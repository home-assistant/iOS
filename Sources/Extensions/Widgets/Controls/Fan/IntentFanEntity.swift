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
struct IntentFanAppEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [IntentFanEntity] {
        await getFanEntities().flatMap(\.1).filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> IntentItemCollection<IntentFanEntity> {
        let fansPerServer = await getFanEntities(matching: string)

        return .init(sections: fansPerServer.map { (key: Server, value: [IntentFanEntity]) in
            .init(
                .init(stringLiteral: key.info.name),
                items: value
            )
        })
    }

    func suggestedEntities() async throws -> IntentItemCollection<IntentFanEntity> {
        let fansPerServer = await getFanEntities()

        return .init(sections: fansPerServer.map { (key: Server, value: [IntentFanEntity]) in
            .init(.init(stringLiteral: key.info.name), items: value)
        })
    }

    private func getFanEntities(matching string: String? = nil) async -> [(Server, [IntentFanEntity])] {
        var fanEntities: [(Server, [IntentFanEntity])] = []
        let entities = ControlEntityProvider(domains: [.fan]).getEntities(matching: string)

        for (server, values) in entities {
            let deviceMap = values.devicesMap(for: server.identifier.rawValue)
            let areasMap = values.areasMap(for: server.identifier.rawValue)
            fanEntities.append((server, values.map({ entity in
                IntentFanEntity(
                    id: entity.id,
                    entityId: entity.entityId,
                    serverId: entity.serverId,
                    areaName: areasMap[entity.entityId]?.name ?? "",
                    deviceName: deviceMap[entity.entityId]?.name ?? "",
                    displayString: entity.name,
                    iconName: entity.icon ?? SFSymbol.fan.rawValue
                )
            })))
        }

        return fanEntities
    }
}
