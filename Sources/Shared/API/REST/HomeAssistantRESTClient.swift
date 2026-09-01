import Foundation
import PromiseKit

/// Minimal authenticated client for Home Assistant's REST API (`/api/…`).
///
/// It exists for callers that can't use the WebSocket connection — chiefly watchOS, where raw and
/// stream sockets are denied by NECP policy on real watch hardware (see `MagicItem.execute`) — so the
/// same server operations can be expressed over `URLSession`, the one transport watchOS reliably
/// supports. It reuses the server's mTLS-aware session and the same bearer token as every other
/// networking path, so client certificates, security exceptions and token refresh behave identically.
///
/// Compiled on every platform (not just watchOS) so its URL building and error handling stay
/// testable from the iOS unit-test target.
public enum HomeAssistantRESTClient {
    public enum Method: String {
        case get = "GET"
        case post = "POST"
    }

    /// Bounded so a dead route fails visibly instead of leaving an App Intent hanging until the
    /// system kills it.
    public static let defaultTimeout: TimeInterval = 30

    /// How long to wait for a bearer token before failing. The refresh request has no watchdog of
    /// its own and `TokenManager` caches the in-flight refresh promise, so a refresh that never
    /// resolves would otherwise hang every subsequent request (same reasoning as
    /// `WatchServiceCallSender`).
    public static let tokenTimeout: TimeInterval = 10

    /// Performs an authenticated request against `/api/` + `path` and returns the raw body.
    ///
    /// `path` is passed as components rather than a joined string so values that need escaping
    /// (entity ids, action names) can't break out of the path.
    public static func send(
        server: Server,
        method: Method = .get,
        path: [String],
        query: [URLQueryItem] = [],
        body: [String: Any]? = nil,
        timeout: TimeInterval = defaultTimeout
    ) async throws -> Data {
        // Synchronous URL evaluation on purpose — see `MagicItem.executeViaREST`. Callers refresh
        // network information before running, so the last-known state is the current one.
        guard let baseURL = server.activeURLUsingLastKnownNetworkState() else {
            throw ServerConnectionError.noActiveURL(server.info.name)
        }

        let url = try url(base: baseURL, path: path, query: query)
        let tokenManager = Current.api(for: server)?.tokenManager ?? TokenManager(server: server)
        let token = try await bearerToken(from: tokenManager)

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.timeoutInterval = timeout
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(HomeAssistantAPI.userAgent, forHTTPHeaderField: "User-Agent")
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        }

        let (data, response) = try await self.data(for: request, server: server)

        if response.statusCode == 401 {
            // The server rejected a token the client still considered valid; invalidate it so the
            // next call refreshes instead of replaying the same rejected credential.
            tokenManager.handleAccessTokenRejected(token)
        }

        guard (200 ..< 300).contains(response.statusCode) else {
            throw HomeAssistantRESTError.unacceptableStatus(
                code: response.statusCode,
                body: String(data: data, encoding: .utf8)
            )
        }

        return data
    }

    /// Performs a request and decodes its JSON body.
    public static func sendForJSON(
        server: Server,
        method: Method = .get,
        path: [String],
        query: [URLQueryItem] = [],
        body: [String: Any]? = nil,
        timeout: TimeInterval = defaultTimeout
    ) async throws -> Any {
        let data = try await send(
            server: server,
            method: method,
            path: path,
            query: query,
            body: body,
            timeout: timeout
        )
        return try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }

    /// Builds `{base}/api/{path…}` with `query` appended. Exposed for tests.
    public static func url(base: URL, path: [String], query: [URLQueryItem] = []) throws -> URL {
        var url = base.appendingPathComponent("api", isDirectory: true)
        for component in path {
            url.appendPathComponent(component)
        }

        guard query.isEmpty == false else { return url }

        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw HomeAssistantAPI.APIError.cantBuildURL
        }
        components.queryItems = query
        guard let queried = components.url else {
            throw HomeAssistantAPI.APIError.cantBuildURL
        }
        return queried
    }

    private static func bearerToken(from tokenManager: TokenManager) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let lock = NSLock()
            var settled = false
            // First caller wins; the loser is discarded so the continuation resumes exactly once.
            // A late token still lands in the shared cache for the next call.
            func settleOnce(_ body: () -> Void) {
                lock.lock()
                let shouldRun = !settled
                settled = true
                lock.unlock()
                if shouldRun { body() }
            }

            // Main queue on purpose — it is the one queue proven to stay serviced on watch
            // hardware (see `MagicItem.executeViaREST`).
            DispatchQueue.main.asyncAfter(deadline: .now() + tokenTimeout) {
                settleOnce {
                    Current.Log.error("Token deadline elapsed for REST request")
                    continuation.resume(throwing: HomeAssistantRESTError.tokenUnavailable)
                }
            }

            tokenManager.bearerToken.done { token, _ in
                settleOnce { continuation.resume(returning: token) }
            }.catch { error in
                settleOnce { continuation.resume(throwing: error) }
            }
        }
    }

    private static func data(for request: URLRequest, server: Server) async throws -> (Data, HTTPURLResponse) {
        let session = HomeAssistantAPI.makeCertificateAwareURLSession(server: server)
        // The session strongly retains its delegate until invalidated; do it once the task ends.
        defer { session.finishTasksAndInvalidate() }

        return try await withCheckedThrowingContinuation { continuation in
            session.dataTask(with: request) { data, response, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let response = response as? HTTPURLResponse else {
                    continuation.resume(throwing: HomeAssistantRESTError.invalidResponse)
                    return
                }
                continuation.resume(returning: (data ?? Data(), response))
            }.resume()
        }
    }
}
