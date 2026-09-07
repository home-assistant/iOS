import AppIntents
import Foundation
import SFSafeSymbols
import Shared

/// An entity a spoken question can report on.
///
/// Its own type rather than `HAAppEntityAppIntentEntity`, whose query is shared with the details and
/// gauge widgets: those legitimately offer diagnostics and sensors with no room, and a question
/// should not. The list here is the same one the control commands offer, widened to what is safe to
/// read.
@available(macOS 13.0, watchOS 9.4, *)
struct ReadableEntityAppEntity: AppEntity, EntityContextRepresentable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: .init(
        "app_intents.readable_entity.entity.name",
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

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(displayString)",
            subtitle: subtitle.map { LocalizedStringResource(stringLiteral: $0) }
        )
    }

    var subtitle: String? {
        contextSubtitle(serverName: serverName)
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
