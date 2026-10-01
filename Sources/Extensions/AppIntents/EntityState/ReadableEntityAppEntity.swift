import AppIntents
import Foundation
import Shared

/// An entity a spoken question can ask about.
///
/// A type of its own for the same reason `ControllableEntityAppEntity` is one: the parameter type is
/// what Siri fills a phrase's list from, and what the system reaches for when a Spotlight result is
/// tapped. Reading a state is harmless, but it is still not what tapping an entity in search should
/// do — the indexed type is left to `ShowEntityDetailsAppIntent` alone, which opens it.
@available(macOS 13.0, watchOS 9.4, *)
struct ReadableEntityAppEntity: AppEntity, EntityContextRepresentable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: .init(
        "app_intents.entity_state.parameter.entity",
        defaultValue: "Entity"
    ))

    static let defaultQuery = ReadableEntityAppEntityQuery()

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

    var domain: Domain? {
        Domain(entityId: entityId)
    }

    /// Deliberately carries no image, so the question's own glyph reaches the Spotlight row rather
    /// than the domain's. See `ControllableEntityAppEntity` for why the glyph is the only part of
    /// that row a command can vary.
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(displayString)",
            subtitle: subtitle.map { LocalizedStringResource(stringLiteral: $0) }
        )
    }

    /// A picker groups by server, but a row stands alone in Siri's disambiguation, where two homes
    /// can share a name — so the server leads the context line once there is more than one.
    var subtitle: String? {
        contextSubtitle(serverName: serverName)
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
