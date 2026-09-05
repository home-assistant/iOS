import AppIntents
import Foundation
import SFSafeSymbols
import Shared

/// An entity a spoken command can switch on or off, across every domain that supports it.
@available(macOS 13.0, watchOS 9.4, *)
struct ControllableEntityAppEntity: AppEntity, EntityContextRepresentable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: .init(
        "app_intents.controllable_entity.entity.name",
        defaultValue: "Controllable Entity"
    ))

    static let defaultQuery = ControllableEntityAppEntityQuery()

    var id: String
    var serverId: String
    var iconName: String
    @Property(title: .init("app_intents.entity.property.entity_id", defaultValue: "Entity ID"))
    var entityId: String
    @Property(title: .init("app_intents.entity.property.name", defaultValue: "Name"))
    var displayString: String
    @Property(title: .init("app_intents.entity.property.area", defaultValue: "Area"))
    var areaName: String?
    @Property(title: .init("app_intents.entity.property.device", defaultValue: "Device"))
    var deviceName: String?
    @Property(title: .init("app_intents.entity.property.floor", defaultValue: "Floor"))
    var floorName: String?
    @Property(title: .init("app_intents.entity.property.server", defaultValue: "Server"))
    var serverName: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(displayString)",
            subtitle: subtitle.map { LocalizedStringResource(stringLiteral: $0) }
        )
    }

    /// Leads with the server when more than one is configured: the picker groups by server, but a row
    /// stands alone in Siri's disambiguation and in a saved shortcut, where two homes can share a name.
    var subtitle: String? {
        guard Current.servers.all.count > 1 else {
            return contextSubtitle
        }
        return EntityContextSubtitle.make(
            serverName: serverName,
            floorName: floorName,
            areaName: areaName,
            deviceName: deviceName,
            entityName: displayString,
            entityId: entityId,
            domain: domain
        )
    }

    /// The domain the command resolves its service from, e.g. `cover` opens rather than turns on.
    var domain: Domain? {
        Domain(entityId: entityId)
    }

    init(
        id: String,
        entityId: String,
        serverId: String,
        serverName: String,
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
        self.displayString = displayString
        self.areaName = areaName
        self.deviceName = deviceName
        self.floorName = floorName
        self.serverName = serverName
    }
}
