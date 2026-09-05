import AppIntents
import Foundation
import SFSafeSymbols
import Shared
import WidgetKit

@available(macOS 13.0, *)
struct HAAppEntityAppIntentEntity: AppEntity, EntityContextRepresentable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Entity")

    static let defaultQuery = HAAppEntityAppIntentEntityQuery()

    var id: String
    @Property(title: .init("app_intents.entity.property.entity_id", defaultValue: "Entity ID"))
    var entityId: String
    var serverId: String
    @Property(title: .init("app_intents.entity.property.server", defaultValue: "Server"))
    var serverName: String
    @Property(title: .init("app_intents.entity.property.area", defaultValue: "Area"))
    var areaName: String?
    @Property(title: .init("app_intents.entity.property.device", defaultValue: "Device"))
    var deviceName: String?
    /// Name of the hardware a child device belongs to. Only the Spotlight index sets it.
    var parentDeviceName: String?
    @Property(title: .init("app_intents.entity.property.floor", defaultValue: "Floor"))
    var floorName: String?
    @Property(title: .init("app_intents.entity.property.name", defaultValue: "Name"))
    var displayString: String
    var iconName: String
    /// Whether the server name leads the context line. Only the Spotlight index sets this, and only
    /// when more than one server is configured: its results stand alone, while every picker already
    /// groups entities under a per-server section.
    var includesServerContext: Bool

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(displayString)",
            subtitle: subtitle.map { LocalizedStringResource(stringLiteral: $0) }
        )
    }

    /// The `Server • Floor • Area • Device` line shown under the entity name.
    var subtitle: String? {
        guard includesServerContext else {
            return contextSubtitle
        }
        return EntityContextSubtitle.make(
            serverName: serverName,
            floorName: floorName,
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
        parentDeviceName: String? = nil,
        floorName: String? = nil,
        displayString: String,
        iconName: String,
        includesServerContext: Bool = false
    ) {
        self.id = id
        self.serverId = serverId
        self.iconName = iconName
        self.includesServerContext = includesServerContext
        self.entityId = entityId
        self.serverName = serverName
        self.areaName = areaName
        self.deviceName = deviceName
        self.parentDeviceName = parentDeviceName
        self.floorName = floorName
        self.displayString = displayString
    }
}

@available(macOS 13.0, *)
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
            let floorMap = values.floorNamesMap(for: server.identifier.rawValue)

            allEntities.append((server, values.map({ entity in
                HAAppEntityAppIntentEntity(
                    id: entity.id,
                    entityId: entity.entityId,
                    serverId: entity.serverId,
                    serverName: server.info.name,
                    areaName: areasMap[entity.entityId]?.name ?? "",
                    deviceName: deviceMap[entity.entityId]?.name ?? "",
                    floorName: floorMap[entity.entityId],
                    displayString: entity.name,
                    iconName: entity.icon ?? SFSymbol.applescriptFill.rawValue
                )
            })))
        }

        return allEntities
    }
}

@available(macOS 13.0, *)
func makeHAEntityIntentItemCollection(
    entities: [(Server, [HAAppEntity])],
    defaultIconName: String
) -> IntentItemCollection<HAAppEntityAppIntentEntity> {
    .init(sections: entities.map { (server: Server, values: [HAAppEntity]) in
        let areasMap = values.areasMap(for: server.identifier.rawValue)
        let floorMap = values.floorNamesMap(for: server.identifier.rawValue)
        return .init(
            .init(stringLiteral: server.info.name),
            items: values.map { entity in
                HAAppEntityAppIntentEntity(
                    id: entity.id,
                    entityId: entity.entityId,
                    serverId: entity.serverId,
                    serverName: server.info.name,
                    areaName: areasMap[entity.entityId]?.name,
                    floorName: floorMap[entity.entityId],
                    displayString: entity.name,
                    iconName: entity.icon ?? defaultIconName
                )
            }
        )
    })
}
