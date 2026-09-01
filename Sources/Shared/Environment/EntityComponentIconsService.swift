import Foundation
import HAKit

public protocol EntityComponentIconsProviderProtocol {
    func iconsMap(for serverId: String) -> EntityComponentIconsMap?
    @discardableResult
    func fetch(for server: Server) async -> EntityComponentIconsMap?
}

/// Fetches and caches, per server, the `entity_component` icon map the frontend uses to resolve
/// entity icons (`frontend/get_icons`). Kept in memory only: the resolved default icon is persisted
/// per entity on `HAAppEntity` (so pickers work offline), while this live map lets state-aware
/// surfaces resolve the current icon without persisting volatile state.
final class EntityComponentIconsService: EntityComponentIconsProviderProtocol {
    static var shared: EntityComponentIconsProviderProtocol = EntityComponentIconsService()

    /// Guards `maps` and `requests`, both of which are read/written from concurrent per-server tasks.
    private let lock = NSLock()
    /// [ServerId: EntityComponentIconsMap]
    private var maps: [String: EntityComponentIconsMap] = [:]
    /// In-flight request per server, so a fetch for one server never cancels another's.
    private var requests: [String: HACancellable] = [:]

    func iconsMap(for serverId: String) -> EntityComponentIconsMap? {
        lock.lock()
        defer { lock.unlock() }
        return maps[serverId]
    }

    @discardableResult
    func fetch(for server: Server) async -> EntityComponentIconsMap? {
        guard server.info.version >= .frontendGetIconsEntityComponent else {
            return nil
        }
        guard let connection = Current.api(for: server)?.connection else {
            Current.Log.error("No API available to fetch entity component icons")
            return nil
        }

        let serverId = server.identifier.rawValue
        lock.lock()
        requests[serverId]?.cancel()
        lock.unlock()

        let map: EntityComponentIconsMap = await withCheckedContinuation { continuation in
            let request = connection.send(
                HATypedRequest<EntityComponentIconsResponse>.frontendGetIcons(category: "entity_component"),
                completion: { result in
                    switch result {
                    case let .success(data):
                        continuation.resume(returning: data.resources)
                    case let .failure(error):
                        Current.Log.error(userInfo: [
                            "Failed to retrieve entity component icons": error.localizedDescription,
                        ])
                        continuation.resume(returning: [:])
                    }
                }
            )
            lock.lock()
            requests[serverId] = request
            lock.unlock()
        }

        lock.lock()
        requests[serverId] = nil
        if !map.isEmpty {
            maps[serverId] = map
        }
        lock.unlock()
        return map
    }
}
