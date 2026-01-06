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
    var areaName: String?
    var deviceName: String?
    var displayString: String
    var iconName: String
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(displayString)",
            subtitle: .init(stringLiteral: subtitle)
        )
    }

    private var subtitle: String {
        var subtitle = ""
        if let areaName {
            subtitle += areaName
        }

        if let deviceName,
           deviceName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != displayString.lowercased()
           .trimmingCharacters(in: .whitespacesAndNewlines) {
            if subtitle.isEmpty {
                subtitle += deviceName
            } else {
                subtitle += " → \(deviceName)"
            }
        }

        return subtitle
    }

    init(
        id: String,
        entityId: String,
        serverId: String,
        serverName: String,
        areaName: String? = nil,
        deviceName: String? = nil,
        displayString: String,
        iconName: String
    ) {
        self.id = id
        self.entityId = entityId
        self.serverId = serverId
        self.serverName = serverName
        self.areaName = areaName
        self.deviceName = deviceName
        self.displayString = displayString
        self.iconName = iconName
    }
}

@available(iOS 16.4, macOS 13.0, watchOS 9.0, *)
struct HAAppEntityAppIntentEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [HAAppEntityAppIntentEntity] {
        getEntities().flatMap(\.1).filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> IntentItemCollection<HAAppEntityAppIntentEntity> {
        .init(sections: getEntities(matching: string).map { (key: Server, value: [HAAppEntityAppIntentEntity]) in
            .init(
                .init(stringLiteral: key.info.name),
                items: value
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
            let deviceMap = values.devicesMap(for: server.identifier.rawValue)
            let areasMap = values.areasMap(for: server.identifier.rawValue)

            allEntities.append((server, values.map({ entity in
                HAAppEntityAppIntentEntity(
                    id: entity.id,
                    entityId: entity.entityId,
                    serverId: entity.serverId,
                    serverName: server.info.name,
                    areaName: areasMap[entity.entityId]?.name ?? "",
                    deviceName: deviceMap[entity.entityId]?.name ?? "",
                    displayString: entity.name,
                    iconName: entity.icon ?? SFSymbol.applescriptFill.rawValue
                )
            })))
        }

        return allEntities
    }
}
