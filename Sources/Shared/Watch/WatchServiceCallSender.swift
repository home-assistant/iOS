import Foundation
import PromiseKit

/// Sends a Home Assistant service call over the REST API from the watch.
///
/// The watch can't hold a WebSocket connection (see `MagicItem.execute`), so screens that control
/// an entity directly — like the light controls screen — post to
/// `/api/services/{domain}/{service}` the same way magic item execution does. Unlike that path,
/// callers here own their UI feedback, so failures just report `false`.
public enum WatchServiceCallSender {
    /// The request body for a service call targeting one entity. Split out so it can be unit tested.
    public static func payload(entityId: String, data: [String: Any]) -> [String: Any] {
        var body = data
        body["entity_id"] = entityId
        return body
    }

    #if os(watchOS)
    /// How long to wait for a bearer token before failing — `TokenManager` caches the in-flight
    /// refresh promise, so a refresh that never resolves would otherwise swallow every call
    /// silently, with `completion` never invoked (same reasoning as `MagicItem.executeViaREST`).
    private static var tokenDeadline: TimeInterval { 10 }

    /// Calls `completion` on the main queue with whether the server accepted the call.
    public static func send(
        domain: Domain,
        service: Service,
        entityId: String,
        data: [String: Any] = [:],
        server: Server,
        completion: @escaping (Bool) -> Void
    ) {
        let finish: (Bool) -> Void = { success in
            DispatchQueue.main.async { completion(success) }
        }
        // Synchronous URL evaluation on purpose — see `MagicItem.executeViaREST`.
        guard let baseURL = server.activeURLUsingLastKnownNetworkState() else {
            Current.Log.error("No active URL sending \(domain.rawValue).\(service.rawValue) from watch")
            finish(false)
            return
        }
        let body: Data
        do {
            body = try JSONSerialization.data(
                withJSONObject: payload(entityId: entityId, data: data),
                options: []
            )
        } catch {
            Current.Log.error("Failed encoding \(domain.rawValue).\(service.rawValue) payload: \(error)")
            finish(false)
            return
        }
        let tokenManager = Current.api(for: server)?.tokenManager ?? TokenManager(server: server)

        let lock = NSLock()
        var settled = false
        // First caller wins; the loser is discarded so `completion` runs exactly once. A late
        // token still lands in the shared cache for the next call.
        func settleOnce(_ body: () -> Void) {
            lock.lock()
            let shouldRun = !settled
            settled = true
            lock.unlock()
            if shouldRun { body() }
        }

        // Deadline so a stuck token refresh fails the call instead of silencing it. Main queue on
        // purpose — it is the one queue proven to stay serviced on watch hardware (see
        // `MagicItem.executeViaREST`).
        DispatchQueue.main.asyncAfter(deadline: .now() + tokenDeadline) {
            settleOnce {
                Current.Log.error(
                    "Token deadline elapsed sending \(domain.rawValue).\(service.rawValue) from watch"
                )
                finish(false)
            }
        }

        tokenManager.bearerToken.done { token, _ in
            settleOnce {
                sendRequest(
                    baseURL: baseURL,
                    domain: domain,
                    service: service,
                    entityId: entityId,
                    body: body,
                    token: token,
                    server: server,
                    finish: finish
                )
            }
        }.catch { error in
            settleOnce {
                Current.Log.error(
                    "Token unavailable sending \(domain.rawValue).\(service.rawValue) from watch: " +
                        error.localizedDescription
                )
                finish(false)
            }
        }
    }

    private static func sendRequest(
        baseURL: URL,
        domain: Domain,
        service: Service,
        entityId: String,
        body: Data,
        token: String,
        server: Server,
        finish: @escaping (Bool) -> Void
    ) {
        let url = baseURL
            .appendingPathComponent("api")
            .appendingPathComponent("services")
            .appendingPathComponent(domain.rawValue)
            .appendingPathComponent(service.rawValue)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // Bounded so a dead route fails visibly instead of hanging the controls for 60s.
        request.timeoutInterval = 10
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(HomeAssistantAPI.userAgent, forHTTPHeaderField: "User-Agent")
        request.httpBody = body
        let session = HomeAssistantAPI.makeCertificateAwareURLSession(server: server)
        let task = session.dataTask(with: request) { [session] _, response, error in
            // The session strongly retains its delegate until invalidated; do it once the task ends.
            defer { session.finishTasksAndInvalidate() }
            if let error {
                Current.Log.error(
                    "REST \(domain.rawValue).\(service.rawValue) for \(entityId) failed: " +
                        error.localizedDescription
                )
                finish(false)
                return
            }
            guard let http = response as? HTTPURLResponse,
                  (200 ..< 300).contains(http.statusCode) else {
                finish(false)
                return
            }
            finish(true)
        }
        task.resume()
    }
    #endif
}
