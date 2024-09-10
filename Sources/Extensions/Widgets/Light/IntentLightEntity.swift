import AppIntents
import Foundation
import GRDB
import Shared

@available(iOS 18.0, *)
struct IntentLightEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Light")

    static let defaultQuery = IntentLightAppEntityQuery()

    // UniqueID: serverId-entityId
    var id: String
    var entityId: String
    var serverId: String
    var displayString: String
    var iconName: String
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayString)")
    }

    init(
        id: String,
        entityId: String,
        serverId: String,
        displayString: String,
        iconName: String
    ) {
        self.id = id
        self.entityId = entityId
        self.serverId = serverId
        self.displayString = displayString
        self.iconName = iconName
    }
}

@available(iOS 18.0, *)
struct IntentLightAppEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [IntentLightEntity] {
        await getLightEntities().flatMap(\.value).filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> IntentItemCollection<IntentLightEntity> {
        let lightsPerServer = await getLightEntities()

        return .init(sections: lightsPerServer.map { (key: Server, value: [IntentLightEntity]) in
            .init(
                .init(stringLiteral: key.info.name),
                items: value.filter({ $0.displayString.lowercased().contains(string.lowercased()) })
            )
        })
    }

    func suggestedEntities() async throws -> IntentItemCollection<IntentLightEntity> {
        let lightsPerServer = await getLightEntities()

        return .init(sections: lightsPerServer.map { (key: Server, value: [IntentLightEntity]) in
            .init(.init(stringLiteral: key.info.name), items: value)
        })
    }

    private func getLightEntities(matching string: String? = nil) async -> [Server: [IntentLightEntity]] {
        await withCheckedContinuation { continuation in
            var entities: [Server: [IntentLightEntity]] = [:]
            var serverCheckedCount = 0
            for server in Current.servers.all.sorted(by: { $0.info.name < $1.info.name }) {
                do {
                    let scripts: [HAAppEntity] = try Current.database().read { db in
                        try HAAppEntity
                            .filter(Column(DatabaseTables.AppEntity.serverId.rawValue) == server.identifier.rawValue)
                            .filter(Column(DatabaseTables.AppEntity.domain.rawValue) == Domain.light.rawValue)
                            .fetchAll(db)
                    }
                    entities[server] = scripts.map({ entity in
                        .init(
                            id: entity.id,
                            entityId: entity.entityId,
                            serverId: server.identifier.rawValue,
                            displayString: entity.name,
                            iconName: entity.icon ?? ""
                        )
                    })
                } catch {
                    Current.Log.error("Failed to load lights from database: \(error.localizedDescription)")
                }
                serverCheckedCount += 1
                if serverCheckedCount == Current.servers.all.count {
                    continuation.resume(returning: entities)
                }
            }
        }
    }
}
