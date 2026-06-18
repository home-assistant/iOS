import AppIntents
import Foundation
import PromiseKit
import SFSafeSymbols
import Shared

@available(iOS 16.4, macOS 13.0, watchOS 9.0, *)
struct IntentAutomationEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Automation")

    static let defaultQuery = IntentAutomationAppEntityQuery()

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
            subtitle: subtitle.map { LocalizedStringResource(stringLiteral: $0) }
        )
    }

    private var subtitle: String? {
        EntityContextSubtitle.make(
            areaName: areaName,
            deviceName: deviceName,
            entityName: displayString,
            entityId: entityId,
            domain: Domain(entityId: entityId)
        )
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
struct IntentAutomationAppEntityQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [IntentAutomationEntity] {
        getAutomationEntities().flatMap(\.1).filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> IntentItemCollection<IntentAutomationEntity> {
        .init(sections: getAutomationEntities(matching: string).map { (key: Server, value: [IntentAutomationEntity]) in
            .init(
                .init(stringLiteral: key.info.name),
                items: value.filter { $0.displayString.lowercased().contains(string.lowercased()) }
            )
        })
    }

    func suggestedEntities() async throws -> IntentItemCollection<IntentAutomationEntity> {
        .init(sections: getAutomationEntities().map { (key: Server, value: [IntentAutomationEntity]) in
            .init(.init(stringLiteral: key.info.name), items: value)
        })
    }

    private func getAutomationEntities(matching string: String? = nil) -> [(Server, [IntentAutomationEntity])] {
        var automationEntities: [(Server, [IntentAutomationEntity])] = []
        let entities = ControlEntityProvider(domains: [.automation]).getEntities(matching: string)

        for (server, values) in entities {
            let deviceMap = values.devicesMap(for: server.identifier.rawValue)
            let areasMap = values.areasMap(for: server.identifier.rawValue)
            automationEntities.append((server, values.map({ entity in
                IntentAutomationEntity(
                    id: entity.id,
                    entityId: entity.entityId,
                    serverId: entity.serverId,
                    serverName: server.info.name,
                    areaName: areasMap[entity.entityId]?.name,
                    deviceName: deviceMap[entity.entityId]?.name,
                    displayString: entity.name,
                    iconName: entity.icon ?? SFSymbol.flowchart.rawValue
                )
            })))
        }

        return automationEntities
    }
}
