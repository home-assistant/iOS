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
        areaName: String? = nil,
        deviceName: String? = nil,
        displayString: String,
        iconName: String
    ) {
        self.id = id
        self.entityId = entityId
        self.serverId = serverId
        self.areaName = areaName
        self.deviceName = deviceName
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
        let lightsPerServer = getLightEntities(matching: string)

        return .init(sections: lightsPerServer.map { (key: Server, value: [IntentLightEntity]) in
            .init(
                .init(stringLiteral: key.info.name),
                items: value
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
            let deviceMap = values.devicesMap(for: server.identifier.rawValue)
            let areasMap = values.areasMap(for: server.identifier.rawValue)
            lightEntities.append((server, values.map({ entity in
                IntentLightEntity(
                    id: entity.id,
                    entityId: entity.entityId,
                    serverId: entity.serverId,
                    areaName: areasMap[entity.entityId]?.name ?? "",
                    deviceName: deviceMap[entity.entityId]?.name ?? "",
                    displayString: entity.name,
                    iconName: entity.icon ?? SFSymbol.lightbulbFill.rawValue
                )
            })))
        }

        return lightEntities
    }
}
