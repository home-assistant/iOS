import AppIntents
import Foundation
import SFSafeSymbols
import Shared
import WidgetKit

@available(iOS 16.4, macOS 13.0, watchOS 9.0, *)
struct HAAppEntityAppIntentEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Entity")

    static let defaultQuery = HAAppEntityAppIntentEntityQuery()

    var id: String
    var entityId: String
    var serverId: String
    var serverName: String
    var displayString: String
    var iconName: String
    var area: String?
    var displayRepresentation: DisplayRepresentation {
        if let area {
            DisplayRepresentation(title: "\(displayString)", subtitle: "\(area)")
        } else {
            DisplayRepresentation(title: "\(displayString)", subtitle: "\(entityId)")
        }
    }

    init(
        id: String,
        entityId: String,
        serverId: String,
        serverName: String,
        displayString: String,
        iconName: String,
        area: String? = nil
    ) {
        self.id = id
        self.entityId = entityId
        self.serverId = serverId
        self.serverName = serverName
        self.displayString = displayString
        self.iconName = iconName
        self.area = area
    }
}

@available(iOS 16.4, macOS 13.0, watchOS 9.0, *)
struct HAAppEntityAppIntentEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [HAAppEntityAppIntentEntity] {
        getEntities().flatMap(\.1).filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> IntentItemCollection<HAAppEntityAppIntentEntity> {
        .init(sections: getEntities().map { (key: Server, value: [HAAppEntityAppIntentEntity]) in
            .init(
                .init(stringLiteral: key.info.name),
                items: value.filter({ $0.displayString.lowercased().contains(string.lowercased()) })
            )
        })
    }

    func suggestedEntities() async throws -> IntentItemCollection<HAAppEntityAppIntentEntity> {
        .init(sections: getEntities().map { (key: Server, value: [HAAppEntityAppIntentEntity]) in
            .init(.init(stringLiteral: key.info.name), items: value)
        })
    }

    private func getEntities(matching string: String? = nil) -> [(Server, [HAAppEntityAppIntentEntity])] {
        var allEntities: [(Server, [HAAppEntityAppIntentEntity])] = []
        let entities = ControlEntityProvider(domains: []).getEntities(matching: string)

        for (server, values) in entities {
            allEntities.append((server, values.map({ entity in
                let area = try? AppArea
                    .fetchAreas(containingEntity: entity.entityId, serverId: entity.serverId)
                    .first?.name
                return HAAppEntityAppIntentEntity(
                    id: entity.id,
                    entityId: entity.entityId,
                    serverId: entity.serverId,
                    serverName: server.info.name,
                    displayString: entity.name,
                    iconName: entity.icon ?? SFSymbol.applescriptFill.rawValue,
                    area: area
                )
            })))
        }

        return allEntities
    }
}
