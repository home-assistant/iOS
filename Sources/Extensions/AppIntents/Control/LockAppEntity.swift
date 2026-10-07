import AppIntents
import Foundation
import SFSafeSymbols
import Shared

/// A lock a spoken command can secure.
@available(macOS 13.0, watchOS 9.4, *)
struct LockAppEntity: AppEntity, EntityContextRepresentable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: .init(
        "app_intents.lock.entity.name",
        defaultValue: "Lock"
    ))

    static let defaultQuery = LockAppEntityQuery()

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
            subtitle: contextSubtitle(serverName: serverName).map { LocalizedStringResource(stringLiteral: $0) }
        )
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
