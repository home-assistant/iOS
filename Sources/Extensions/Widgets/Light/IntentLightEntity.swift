import AppIntents
import Foundation
import GRDB
import SFSafeSymbols
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
        getLightEntities().flatMap(\.1).filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> IntentItemCollection<IntentLightEntity> {
        let lightsPerServer = getLightEntities()

        return .init(sections: lightsPerServer.map { (key: Server, value: [IntentLightEntity]) in
            .init(
                .init(stringLiteral: key.info.name),
                items: value.filter({ $0.displayString.lowercased().contains(string.lowercased()) })
            )
        })
    }

    func suggestedEntities() async throws -> IntentItemCollection<IntentLightEntity> {
        let lightsPerServer = getLightEntities()

        return .init(sections: lightsPerServer.map { (key: Server, value: [IntentLightEntity]) in
            .init(.init(stringLiteral: key.info.name), items: value)
        })
    }

    private func getLightEntities(matching string: String? = nil) -> [(Server, [IntentLightEntity])] {
        var lightEntities: [(Server, [IntentLightEntity])] = []
        let entities = ControlEntityProvider(domains: [.light]).getEntities(matching: string)

        for (server, values) in entities {
            lightEntities.append((server, values.map({ entity in
                IntentLightEntity(
                    id: entity.id,
                    entityId: entity.entityId,
                    serverId: entity.serverId,
                    displayString: entity.name,
                    iconName: entity.icon ?? SFSymbol.lightbulbFill.rawValue
                )
            })))
        }

        return lightEntities
    }
}
