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

    private var request: HACancellable?
    /// [ServerId: EntityComponentIconsMap]
    private var maps: [String: EntityComponentIconsMap] = [:]

    func iconsMap(for serverId: String) -> EntityComponentIconsMap? {
        maps[serverId]
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

        request?.cancel()
        let map: EntityComponentIconsMap = await withCheckedContinuation { continuation in
            request = connection.send(
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
        }
        if !map.isEmpty {
            maps[server.identifier.rawValue] = map
        }
        return map
    }
}
