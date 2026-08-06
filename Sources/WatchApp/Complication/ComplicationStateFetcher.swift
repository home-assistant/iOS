import Foundation
import PromiseKit
import Shared

/// Fetches live data for watch-rendered complications directly from Home Assistant over REST,
/// reusing the server's active URL and bearer token.
enum ComplicationStateFetcher {
    struct EntityState {
        let state: String
        let attributes: [String: Any]
    }

    private static func tokenManager(for server: Server) -> TokenManager {
        Current.api(for: server)?.tokenManager ?? TokenManager(server: server)
    }

    private static func bearerToken(for server: Server) async -> String? {
        let tokenManager = Self.tokenManager(for: server)
        return try? await withCheckedThrowingContinuation { continuation in
            tokenManager.bearerToken.done { token, _ in
                continuation.resume(returning: token)
            }.catch { error in
                continuation.resume(throwing: error)
            }
        }
    }

    /// Performs `request` on the server's mTLS/self-signed-aware session (so local servers work),
    /// invalidating the session afterwards as `MagicItem.sendRESTServiceCall` does. On failure the
    /// data is nil and `failure` says why (transport error, HTTP status), so diagnostics can show
    /// the actual cause instead of a generic "unavailable".
    /// `token` is the bearer already applied to `request`: when the server answers 401, that exact
    /// token is reported rejected so the next fetch refreshes instead of re-sending it — otherwise
    /// every refresh cycle logs invalid auth server-side until the watch's IP gets banned.
    /// Bounded so a slow or unreachable server can't hold a fetch open for `URLSession`'s 60s
    /// default: the watch's background-refresh task force-completes at ~10s, so an over-budget fetch
    /// would suspend the app before the fresh values were written, freezing the complication at its
    /// previous value. Mirrors the widget self-fetch's own bound.
    private static let fetchTimeout: TimeInterval = 8

    private static func boundedSessionConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = fetchTimeout
        configuration.timeoutIntervalForResource = fetchTimeout
        configuration.waitsForConnectivity = false
        return configuration
    }

    private static func data(
        for request: URLRequest,
        server: Server,
        token: String
    ) async -> (data: Data?, failure: String?) {
        let session = HomeAssistantAPI.makeCertificateAwareURLSession(
            server: server,
            configuration: boundedSessionConfiguration()
        )
        defer { session.finishTasksAndInvalidate() }
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                Current.Log.error("[Complication] no HTTP response for \(request.url?.absoluteString ?? "?")")
                return (nil, "no HTTP response")
            }
            guard (200 ..< 300).contains(http.statusCode) else {
                Current.Log.error("[Complication] HTTP \(http.statusCode) for \(request.url?.absoluteString ?? "?")")
                if http.statusCode == 401 {
                    tokenManager(for: server).handleAccessTokenRejected(token)
                }
                return (nil, "HTTP \(http.statusCode)")
            }
            return (data, nil)
        } catch {
            Current.Log.error("[Complication] request failed \(request.url?.absoluteString ?? "?"): \(error)")
            return (nil, error.localizedDescription)
        }
    }

    static func fetchState(entityId: String, server: Server) async -> (state: EntityState?, failure: String?) {
        guard let baseURL = await server.activeURL() else {
            Current.Log.error("[Complication] no active URL for server \(server.identifier.rawValue)")
            return (nil, "no server URL reachable from the watch")
        }
        guard let token = await bearerToken(for: server) else {
            Current.Log.error("[Complication] no bearer token for server \(server.identifier.rawValue)")
            return (nil, "couldn't get an access token")
        }
        Current.Log.info("[Complication] fetching state for \(entityId) at \(baseURL.absoluteString)")
        var request = URLRequest(url: baseURL.appendingPathComponent("api/states/\(entityId)"))
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(HomeAssistantAPI.userAgent, forHTTPHeaderField: "User-Agent")
        let result = await data(for: request, server: server, token: token)
        guard let data = result.data else {
            return (nil, result.failure)
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let state = json["state"] as? String else {
            return (nil, "unexpected response body")
        }
        return (EntityState(state: state, attributes: json["attributes"] as? [String: Any] ?? [:]), nil)
    }

    /// Snapshot everything the watch-widget extension needs to self-fetch this server over REST on its
    /// own WidgetKit budget (it can't link the networking stack to derive these itself). Mirrors the
    /// inputs `fetchState` uses: the resolved base URL, a bearer token, and the mTLS/self-signed material.
    static func credential(for server: Server) async -> WatchWidgetServerCredential? {
        // Resolve the URL and ensure a currently-valid access token (refreshing if needed). Reading
        // `server.info.token` afterwards gives us the matching expiration + long-lived refresh token, so
        // the widget can mint its own fresh access tokens on its budget instead of relying on this snapshot.
        guard let baseURL = await server.activeURL(), await bearerToken(for: server) != nil else {
            return nil
        }
        let tokenInfo = server.info.token
        return WatchWidgetServerCredential(
            serverId: server.identifier.rawValue,
            baseURL: baseURL,
            token: tokenInfo.accessToken,
            expiration: tokenInfo.expiration,
            refreshToken: tokenInfo.refreshToken,
            clientID: WatchWidgetServerCredential.clientID(isDebug: Current.appConfiguration == .debug),
            clientCertLabel: server.info.connection.clientCertificate?.keychainIdentifier,
            trustExceptions: server.info.connection.securityExceptions.rawExceptionData
        )
    }

    static func renderTemplate(_ template: String, server: Server) async -> String? {
        guard !template.isEmpty, let baseURL = await server.activeURL(),
              let token = await bearerToken(for: server) else {
            return nil
        }
        var request = URLRequest(url: baseURL.appendingPathComponent("api/template"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(HomeAssistantAPI.userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["template": template])
        guard let data = await data(for: request, server: server, token: token).data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
