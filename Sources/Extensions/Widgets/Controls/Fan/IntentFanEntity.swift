import AppIntents
import Foundation
import GRDB
import SFSafeSymbols
import Shared

@available(iOS 18.0, *)
struct IntentFanEntity: AppEntity, EntityContextRepresentable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Fan")

    static let defaultQuery = IntentFanAppEntityQuery()

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
    var iconName: String
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
        iconName: String
    ) {
        self.id = id
        self.serverId = serverId
        self.iconName = iconName
        self.entityId = entityId
        self.areaName = areaName
        self.deviceName = deviceName
        self.floorName = floorName
        self.displayString = displayString
    }
}

@available(iOS 18.0, *)
struct IntentFanAppEntityQuery: EntityQuery, EntityStringQuery {
    #if WIDGET_EXTENSION
    @IntentParameterDependency<ControlFanConfiguration>(\.$server)
    var config
    #endif

    func entities(for identifiers: [String]) async throws -> [IntentFanEntity] {
        await getFanEntities().flatMap(\.1).filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> IntentItemCollection<IntentFanEntity> {
        await collection(for: getFanEntities(matching: string))
    }

    func suggestedEntities() async throws -> IntentItemCollection<IntentFanEntity> {
        await collection(for: getFanEntities())
    }

    /// Scopes the list to the server picked in the configuration (flat list). When no server is
    /// selected (e.g. a widget configured before this option existed), falls back to grouping
    /// every server's entities into sections.
    private func collection(
        for entitiesPerServer: [(Server, [IntentFanEntity])]
    ) -> IntentItemCollection<IntentFanEntity> {
        #if WIDGET_EXTENSION
        if let server = config?.server {
            let items = entitiesPerServer.first { $0.0.identifier.rawValue == server.id }?.1 ?? []
            return .init(items: items)
        }
        #endif
        return .init(sections: entitiesPerServer.map { server, items in
            .init(.init(stringLiteral: server.info.name), items: items)
        })
    }

    private func getFanEntities(matching string: String? = nil) async -> [(Server, [IntentFanEntity])] {
        var fanEntities: [(Server, [IntentFanEntity])] = []
        let entities = ControlEntityProvider(domains: [.fan]).getEntities(matching: string)

        for (server, values) in entities {
            let deviceMap = values.devicesMap(for: server.identifier.rawValue)
            let areasMap = values.areasMap(for: server.identifier.rawValue)
            let floorMap = values.floorNamesMap(for: server.identifier.rawValue)
            fanEntities.append((server, values.map({ entity in
                IntentFanEntity(
                    id: entity.id,
                    entityId: entity.entityId,
                    serverId: entity.serverId,
                    areaName: areasMap[entity.entityId]?.name,
                    deviceName: deviceMap[entity.entityId]?.name,
                    floorName: floorMap[entity.entityId],
                    displayString: entity.name,
                    iconName: entity.icon ?? SFSymbol.fan.rawValue
                )
            })))
        }

        return fanEntities
    }
}
