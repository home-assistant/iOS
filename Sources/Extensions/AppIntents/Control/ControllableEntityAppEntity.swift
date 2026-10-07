import AppIntents
import Foundation
import Shared

/// An entity a spoken command can switch on or off, or a whole room's worth of them.
///
/// A type of its own rather than the shared `HAAppEntityAppIntentEntity`, for the same reason
/// `OpenableEntityAppEntity` is one: Siri and Spotlight take a phrase's entity list — and what a
/// tapped Spotlight result does — from the parameter type itself. While this command shared the type
/// the Spotlight index publishes, tapping a search result ran "turn off" instead of opening the
/// entity, with nothing in the row to say so. Keeping the command on its own type leaves the indexed
/// one to `ShowEntityDetailsAppIntent` alone.
@available(macOS 13.0, watchOS 9.4, *)
struct ControllableEntityAppEntity: AppEntity, EntityContextRepresentable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: .init(
        "app_intents.controllable_entity.parameter.entity",
        defaultValue: "Entity"
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

    /// The domain the command resolves its service from, e.g. a scene activates where a light
    /// switches.
    var domain: Domain? {
        areaTarget?.domain ?? Domain(entityId: entityId)
    }

    /// Deliberately carries no image, which is what lets the command's own glyph reach the row.
    ///
    /// Spotlight builds one row per shortcut per entity and titles every one of them with the entity's
    /// name, so a light turns up as a column of rows reading the same thing. The glyph is the only part
    /// of that row a command can vary — the system draws this image where there is one and falls back
    /// to the App Shortcut's `systemImageName` where there is not — so leaving it out is what makes
    /// switching, dimming and asking distinguishable at a glance. `HomeAssistantAppShortcuts` holds
    /// the symbols and the test that keeps them distinct.
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
