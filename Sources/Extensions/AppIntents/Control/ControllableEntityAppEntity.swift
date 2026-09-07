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
    /// Set when this stands for a whole area's worth of one domain rather than a single entity, in
    /// which case `entityId` is empty and the command targets the area instead.
    var areaTarget: AreaTarget?
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

    /// An area row already names its area in the title, so it takes the server as its second line
    /// (and nothing at all when there is only one) rather than repeating itself.
    var subtitle: String? {
        guard areaTarget == nil else {
            return Current.servers.all.count > 1 ? serverName : nil
        }
        return contextSubtitle(serverName: serverName)
    }

    /// The domain the command resolves its service from, e.g. `cover` opens rather than turns on.
    var domain: Domain? {
        areaTarget?.domain ?? Domain(entityId: entityId)
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

    /// What a service call should be addressed to: one entity, or the whole area this stands for.
    ///
    /// Home Assistant scopes an area target by the calling service's domain, so `light.turn_on`
    /// against an area reaches its lights and nothing else in the room.
    var serviceTarget: [String: Any] {
        if let areaTarget {
            return ["area_id": areaTarget.areaId]
        }
        return ["entity_id": entityId]
    }

    /// A whole area of one domain, standing in for every entity of that kind in the room.
    init(areaTarget: AreaTarget, serverId: String, serverName: String) {
        self.id = areaTarget.id(serverId: serverId)
        self.serverId = serverId
        self.iconName = areaTarget.iconName
        self.areaTarget = areaTarget
        self.entityId = ""
        self.displayString = areaTarget.displayName
        self.areaName = areaTarget.areaName
        self.deviceName = nil
        self.floorName = nil
        self.serverName = serverName
    }
}
