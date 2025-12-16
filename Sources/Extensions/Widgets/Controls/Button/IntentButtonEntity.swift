import AppIntents
import Foundation
import GRDB
import SFSafeSymbols
import Shared

@available(iOS 18.0, *)
struct IntentButtonEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Button")

    static let defaultQuery = IntentButtonAppEntityQuery()

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
struct IntentButtonAppEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [IntentButtonEntity] {
        await getButtonEntities().flatMap(\.1).filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> IntentItemCollection<IntentButtonEntity> {
        let buttonsPerServer = await getButtonEntities()

        return .init(sections: buttonsPerServer.map { (key: Server, value: [IntentButtonEntity]) in
            .init(
                .init(stringLiteral: key.info.name),
                items: value.filter({ $0.displayString.lowercased().contains(string.lowercased()) })
            )
        })
    }

    func suggestedEntities() async throws -> IntentItemCollection<IntentButtonEntity> {
        let buttonsPerServer = await getButtonEntities()

        return .init(sections: buttonsPerServer.map { (key: Server, value: [IntentButtonEntity]) in
            .init(.init(stringLiteral: key.info.name), items: value)
        })
    }

    private func getButtonEntities(matching string: String? = nil) async -> [(Server, [IntentButtonEntity])] {
        var buttonEntities: [(Server, [IntentButtonEntity])] = []
        let entities = ControlEntityProvider(domains: [.button, .inputButton]).getEntities(matching: string)

        for (server, values) in entities {
            buttonEntities.append((server, values.map({ entity in
                IntentButtonEntity(
                    id: entity.id,
                    entityId: entity.entityId,
                    serverId: entity.serverId,
                    displayString: entity.name,
                    iconName: entity.icon ?? SFSymbol.circleCircle.rawValue
                )
            })))
        }

        return buttonEntities
    }
}
