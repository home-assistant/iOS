import Foundation
import HAKit

/// Fetches a single entity's current state over the Home Assistant REST API.
///
/// The watch can't hold a WebSocket subscription (see `MagicItem.execute`), so visible rows poll
/// this endpoint instead. Parsing is separate from networking so it can be unit tested.
public enum WatchEntityStateFetcher {
    /// Decodes a `GET /api/states/{entity_id}` response body with the same HAKit model the
    /// WebSocket pipeline uses.
    public static func entity(from data: Data) throws -> HAEntity {
        try HAEntity(data: HAData(value: JSONSerialization.jsonObject(with: data)))
    }

    #if os(watchOS)
    /// Calls `completion` on the main queue, with `nil` on any failure — polling keeps showing the
    /// last known state rather than surfacing transient fetch errors.
    public static func fetchState(
        entityId: String,
        server: Server,
        completion: @escaping (HAEntity?) -> Void
    ) {
        let finish: (HAEntity?) -> Void = { entity in
            DispatchQueue.main.async { completion(entity) }
        }
        // Synchronous URL evaluation on purpose — see `MagicItem.executeViaREST`.
        guard let baseURL = server.activeURLUsingLastKnownNetworkState() else {
            finish(nil)
            return
        }
        let tokenManager = Current.api(for: server)?.tokenManager ?? TokenManager(server: server)
        tokenManager.bearerToken.done { token, _ in
            let url = baseURL
                .appendingPathComponent("api")
                .appendingPathComponent("states")
                .appendingPathComponent(entityId)
            var request = URLRequest(url: url)
            // Bounded below the poll interval so overlapping requests don't pile up.
            request.timeoutInterval = 4
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(HomeAssistantAPI.userAgent, forHTTPHeaderField: "User-Agent")
            let session = HomeAssistantAPI.makeCertificateAwareURLSession(server: server)
            let task = session.dataTask(with: request) { [session] data, response, _ in
                // The session strongly retains its delegate until invalidated; do it once the task ends.
                defer { session.finishTasksAndInvalidate() }
                guard let data,
                      let http = response as? HTTPURLResponse,
                      (200 ..< 300).contains(http.statusCode) else {
                    // The server rejected a token the client still considered valid; stop polling
                    // with it, or every cycle logs invalid auth server-side until an IP ban.
                    if (response as? HTTPURLResponse)?.statusCode == 401 {
                        tokenManager.handleAccessTokenRejected(token)
                    }
                    finish(nil)
                    return
                }
                finish(try? Self.entity(from: data))
            }
            task.resume()
        }.catch { _ in
            finish(nil)
        }
    }
    #endif
}
