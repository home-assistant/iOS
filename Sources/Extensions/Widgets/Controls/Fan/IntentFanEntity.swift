import AppIntents
import Foundation
import GRDB
import SFSafeSymbols
import Shared

@available(iOS 18.0, macOS 15.0, *)
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
    var parentDeviceName: String?
    var contextReach: EntityContextReach = .device
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
        parentDeviceName: String? = nil,
        contextReach: EntityContextReach = .device,
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
        self.parentDeviceName = parentDeviceName
        self.contextReach = contextReach
        self.floorName = floorName
        self.displayString = displayString
    }
}

@available(iOS 18.0, macOS 15.0, *)
struct IntentFanAppEntityQuery: EntityQuery, EntityStringQuery {
    // The control's configuration reached the Mac in macOS 26, later than this query, which cannot depend
    // on a type newer than itself: on the Mac the list is always grouped by server.
    #if WIDGET_EXTENSION && !os(macOS)
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
        #if WIDGET_EXTENSION && !os(macOS)
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
            let deviceContexts = values.deviceContexts(for: server.identifier.rawValue)
            let areasMap = values.areasMap(for: server.identifier.rawValue)
            let floorMap = values.floorNamesMap(for: server.identifier.rawValue)
            fanEntities.append((server, values.map({ entity in
                IntentFanEntity(
                    id: entity.id,
                    entityId: entity.entityId,
                    serverId: entity.serverId,
                    areaName: areasMap[entity.entityId]?.name,
                    deviceName: deviceContexts[entity.entityId]?.deviceName,
                    parentDeviceName: deviceContexts[entity.entityId]?.parentDeviceName,
                    contextReach: deviceContexts[entity.entityId]?.reach ?? .device,
                    floorName: floorMap[entity.entityId],
                    displayString: entity.name,
                    iconName: entity.icon ?? SFSymbol.fan.rawValue
                )
            })))
        }

        return fanEntities
    }
}
