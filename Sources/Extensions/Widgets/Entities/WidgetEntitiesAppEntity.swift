import AppIntents
import Foundation
import Shared

/// One entity as picked in the entities widget configuration.
///
/// `id` is the entity's server-unique id (`serverId-entityId`), the same value the app's entity
/// table uses, so a saved configuration resolves straight back to its row.
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct WidgetEntitiesAppEntity: AppEntity, EntityContextRepresentable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: .init("widgets.parameters.entity", defaultValue: "Entity")
    )

    static let defaultQuery = WidgetEntitiesAppEntityQuery()

    var id: String
    var entityId: String
    var serverId: String
    var areaName: String?
    var deviceName: String?
    var floorName: String?
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
        self.entityId = entityId
        self.serverId = serverId
        self.areaName = areaName
        self.deviceName = deviceName
        self.floorName = floorName
        self.displayString = displayString
        self.icon = icon
    }

    /// The item the widget renders and acts on for this pick.
    var magicItem: MagicItem {
        MagicItem(id: entityId, serverId: serverId, type: .entity)
    }
}
