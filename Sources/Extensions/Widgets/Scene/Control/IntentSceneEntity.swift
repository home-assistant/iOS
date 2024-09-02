import AppIntents
import Foundation
import PromiseKit
import Shared

@available(iOS 16.4, macOS 13.0, watchOS 9.0, *)
struct IntentSceneEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Script")

    static let defaultQuery = IntentSceneAppEntityQuery()

    var id: String
    var serverId: String
    var serverName: String
    var displayString: String
    var iconName: String
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayString)")
    }

    init(
        id: String,
        serverId: String,
        serverName: String,
        displayString: String,
        iconName: String
    ) {
        self.id = id
        self.serverId = serverId
        self.serverName = serverName
        self.displayString = displayString
        self.iconName = iconName
    }
}

@available(iOS 16.4, macOS 13.0, watchOS 9.0, *)
struct IntentSceneAppEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [IntentSceneEntity] {
        await getSceneEntities().flatMap(\.value).filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> IntentItemCollection<IntentSceneEntity> {
        let scenesPerServer = await getSceneEntities()

        return .init(sections: scenesPerServer.map { (key: Server, value: [IntentSceneEntity]) in
            .init(.init(stringLiteral: key.info.name), items: value)
        })
    }

    func suggestedEntities() async throws -> IntentItemCollection<IntentSceneEntity> {
        let scriptsPerServer = await getSceneEntities()

        return .init(sections: scriptsPerServer.map { (key: Server, value: [IntentSceneEntity]) in
            .init(.init(stringLiteral: key.info.name), items: value)
        })
    }

    private func getSceneEntities(matching string: String? = nil) async -> [Server: [IntentSceneEntity]] {
        await withCheckedContinuation { continuation in
            var entities: [Server: [IntentSceneEntity]] = [:]
            var serverCheckedCount = 0
            for server in Current.servers.all.sorted(by: { $0.info.name < $1.info.name }) {
                (
                    Current.diskCache
                        .value(
                            for: HAScene
                                .cacheKey(serverId: server.identifier.rawValue)
                        ) as? Promise<[HAScene]>
                )?.pipe(to: { result in
                    switch result {
                    case let .fulfilled(scripts):
                        var scripts = scripts.sorted(by: { $0.name ?? "" < $1.name ?? "" })
                        if let string {
                            scripts = scripts.filter { $0.name?.contains(string) ?? false }
                        }

                        entities[server] = scripts.compactMap { script in
                            IntentSceneEntity(
                                id: script.id,
                                serverId: server.identifier.rawValue,
                                serverName: server.info.name,
                                displayString: script.name ?? "Unknown",
                                iconName: script.iconName ?? ""
                            )
                        }
                    case let .rejected(error):
                        Current.Log
                            .error(
                                "Failed to get scripts cache for server identifier: \(server.identifier.rawValue), error: \(error.localizedDescription)"
                            )
                    }
                    serverCheckedCount += 1
                    if serverCheckedCount == Current.servers.all.count {
                        continuation.resume(returning: entities)
                    }
                })
            }
        }
    }
}
