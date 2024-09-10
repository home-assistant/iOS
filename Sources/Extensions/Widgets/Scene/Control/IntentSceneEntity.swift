import AppIntents
import Foundation
import GRDB
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
            .init(
                .init(stringLiteral: key.info.name),
                items: value.filter({ $0.displayString.lowercased().contains(string.lowercased()) })
            )
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
                do {
                    var scenes: [HAAppEntity] = try Current.database().read { db in
                        try HAAppEntity
                            .filter(Column(DatabaseTables.AppEntity.serverId.rawValue) == server.identifier.rawValue)
                            .filter(Column(DatabaseTables.AppEntity.domain.rawValue) == Domain.scene.rawValue)
                            .fetchAll(db)
                    }
                    scenes = scenes.sorted(by: { $0.name < $1.name })
                    if let string {
                        scenes = scenes.filter { $0.name.contains(string) }
                    }

                    entities[server] = scenes.map({ entity in
                        .init(
                            id: entity.id,
                            serverId: server.identifier.rawValue,
                            serverName: server.info.name,
                            displayString: entity.name,
                            iconName: entity.icon ?? ""
                        )
                    })
                } catch {
                    Current.Log.error("Failed to load scripts from database: \(error.localizedDescription)")
                }
                serverCheckedCount += 1
                if serverCheckedCount == Current.servers.all.count {
                    continuation.resume(returning: entities)
                }
            }
        }
    }
}
