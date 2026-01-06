import AppIntents
import Foundation
import GRDB
import SFSafeSymbols
import Shared

@available(iOS 18.0, *)
struct IntentSwitchEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Switch")

    static let defaultQuery = IntentSwitchAppEntityQuery()

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
struct IntentSwitchAppEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [IntentSwitchEntity] {
        await getSwitchEntities().flatMap(\.1).filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> IntentItemCollection<IntentSwitchEntity> {
        let switchesPerServer = await getSwitchEntities(matching: string)

        return .init(sections: switchesPerServer.map { (key: Server, value: [IntentSwitchEntity]) in
            .init(
                .init(stringLiteral: key.info.name),
                items: value
            )
        })
    }

    func suggestedEntities() async throws -> IntentItemCollection<IntentSwitchEntity> {
        let switchesPerServer = await getSwitchEntities()

        return .init(sections: switchesPerServer.map { (key: Server, value: [IntentSwitchEntity]) in
            .init(.init(stringLiteral: key.info.name), items: value)
        })
    }

    private func getSwitchEntities(matching string: String? = nil) async -> [(Server, [IntentSwitchEntity])] {
        var switchEntities: [(Server, [IntentSwitchEntity])] = []
        let entities = ControlEntityProvider(domains: [.switch, .inputBoolean]).getEntities(matching: string)

        for (server, values) in entities {
            let deviceMap = values.devicesMap(for: server.identifier.rawValue)
            let areasMap = values.areasMap(for: server.identifier.rawValue)
            switchEntities.append((server, values.map({ entity in
                IntentSwitchEntity(
                    id: entity.id,
                    entityId: entity.entityId,
                    serverId: entity.serverId,
                    areaName: areasMap[entity.entityId]?.name ?? "",
                    deviceName: deviceMap[entity.entityId]?.name ?? "",
                    displayString: entity.name,
                    iconName: entity.icon ?? SFSymbol.lightswitchOnFill.rawValue
                )
            })))
        }

        return switchEntities
    }
}
