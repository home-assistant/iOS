import AppIntents
import Foundation
import SFSafeSymbols
import Shared

@available(iOS 17.0, macOS 13.0, tvOS 16.0, *)
struct IntentSensorsAppEntity: AppEntity, EntityContextRepresentable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Sensor")

    static let defaultQuery = IntentSensorsAppEntityQuery()

    // UniqueID: serverId-entityId
    var id: String
    @Property(title: .init("app_intents.entity.property.entity_id", defaultValue: "Entity ID"))
    var entityId: String
    var serverId: String
    @Property(title: .init("app_intents.entity.property.area", defaultValue: "Area"))
    var areaName: String?
    @Property(title: .init("app_intents.entity.property.device", defaultValue: "Device"))
    var deviceName: String?
    @Property(title: .init("app_intents.entity.property.floor", defaultValue: "Floor"))
    var floorName: String?
    @Property(title: .init("app_intents.entity.property.name", defaultValue: "Name"))
    var displayString: String
    var icon: String?

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(displayString)",
            subtitle: contextSubtitle.map { LocalizedStringResource(stringLiteral: $0) }
        )
    }

    init(
        id: String,
        entityId: String,
        serverId: String,
        areaName: String? = nil,
        deviceName: String? = nil,
        floorName: String? = nil,
        displayString: String,
        icon: String?
    ) {
        self.id = id
        self.serverId = serverId
        self.icon = icon
        self.entityId = entityId
        self.areaName = areaName
        self.deviceName = deviceName
        self.floorName = floorName
        self.displayString = displayString
    }
}

@available(iOS 17.0, macOS 13.0, tvOS 16.0, *)
struct IntentSensorsAppEntityQuery: EntityQuery {
    @IntentParameterDependency<WidgetSensorsAppIntent>(\.$server)
    var config

    func entities(for identifiers: [IntentSensorsAppEntity.ID]) async throws -> [IntentSensorsAppEntity] {
        getSensorEntities().flatMap(\.1).filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> IntentItemCollection<IntentSensorsAppEntity> {
        collection(for: getSensorEntities())
    }

    /// Scopes the list to the server picked in the configuration (flat list). When no server is
    /// selected (e.g. a widget configured before this option existed), falls back to grouping
    /// every server's entities into sections.
    private func collection(
        for entitiesPerServer: [(Server, [IntentSensorsAppEntity])]
    ) -> IntentItemCollection<IntentSensorsAppEntity> {
        if let server = config?.server {
            let items = entitiesPerServer.first { $0.0.identifier.rawValue == server.id }?.1 ?? []
            return .init(items: items)
        }
        return .init(sections: entitiesPerServer.map { server, items in
            .init(.init(stringLiteral: server.info.name), items: items)
        })
    }

    func defaultResult() async -> IntentSensorsAppEntity? {
        let entitiesPerServer = getSensorEntities()
        // Respect the server chosen in the configuration so we don't default to a sensor from a
        // different server than the one selected.
        if let server = config?.server {
            return entitiesPerServer.first { $0.0.identifier.rawValue == server.id }?.1.first
        }
        return entitiesPerServer.flatMap(\.1).first
    }

    private func getSensorEntities(matching string: String? = nil) -> [(Server, [IntentSensorsAppEntity])] {
        var sensorEntities: [(Server, [IntentSensorsAppEntity])] = []
        let entities = ControlEntityProvider(domains: WidgetSensorsConfig.domains).getEntities(matching: string)

        for (server, values) in entities {
            let deviceMap = values.devicesMap(for: server.identifier.rawValue)
            let areasMap = values.areasMap(for: server.identifier.rawValue)
            let floorMap = values.floorNamesMap(for: server.identifier.rawValue)
            sensorEntities.append((server, values.map({ entity in
                IntentSensorsAppEntity(
                    id: entity.id,
                    entityId: entity.entityId,
                    serverId: entity.serverId,
                    areaName: areasMap[entity.entityId]?.name,
                    deviceName: deviceMap[entity.entityId]?.name,
                    floorName: floorMap[entity.entityId],
                    displayString: entity.name,
                    icon: entity.icon
                )
            })))
        }

        return sensorEntities
    }
}
