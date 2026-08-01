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
        tokenManager.bearerToken.done { token, _ in
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
        }.catch { error in
            Current.Log.error(
                "Token unavailable sending \(domain.rawValue).\(service.rawValue) from watch: " +
                    error.localizedDescription
            )
            finish(false)
        }
    }
    #endif
}
