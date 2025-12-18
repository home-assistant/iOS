import AppIntents
import Foundation
import GRDB
import SFSafeSymbols
import Shared

@available(iOS 18.0, *)
struct IntentFanEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Fan")

    static let defaultQuery = IntentFanAppEntityQuery()

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
struct IntentFanAppEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [IntentFanEntity] {
        getFanEntities().flatMap(\.1).filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> IntentItemCollection<IntentFanEntity> {
        let fansPerServer = getFanEntities()

        return .init(sections: fansPerServer.map { (key: Server, value: [IntentFanEntity]) in
            .init(
                .init(stringLiteral: key.info.name),
                items: value.filter({ $0.displayString.lowercased().contains(string.lowercased()) })
            )
        })
    }

    func suggestedEntities() async throws -> IntentItemCollection<IntentFanEntity> {
        let fansPerServer = getFanEntities()

        return .init(sections: fansPerServer.map { (key: Server, value: [IntentFanEntity]) in
            .init(.init(stringLiteral: key.info.name), items: value)
        })
    }

    private func getFanEntities(matching string: String? = nil) -> [(Server, [IntentFanEntity])] {
        var fanEntities: [(Server, [IntentFanEntity])] = []
        let entities = ControlEntityProvider(domains: [.fan]).getEntities(matching: string)

        for (server, values) in entities {
            fanEntities.append((server, values.map({ entity in
                IntentFanEntity(
                    id: entity.id,
                    entityId: entity.entityId,
                    serverId: entity.serverId,
                    displayString: entity.name,
                    iconName: entity.icon ?? SFSymbol.fan.rawValue
                )
            })))
        }

        return fanEntities
    }
}
