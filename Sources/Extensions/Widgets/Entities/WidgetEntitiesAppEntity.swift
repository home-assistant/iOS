import AppIntents
import Foundation
import SFSafeSymbols
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
    /// The Material Design icon the entity is drawn with, already resolved through the same
    /// precedence the app's pickers use: the entity's own icon, then the frontend default, then
    /// the domain's.
    var icon: String?

    /// Icon, name and the `Floor • Area • Device` context line, the way the app's other entity
    /// pickers draw their rows.
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(displayString)",
            subtitle: contextSubtitle.map { LocalizedStringResource(stringLiteral: $0) },
            image: displayRepresentationImage
        )
    }

    private var displayRepresentationImage: DisplayRepresentation.Image {
        guard let data = icon.flatMap(MaterialDesignIcons.pngData(forServersideValue:)) else {
            return .init(systemName: SFSymbol.squareGrid2x2.rawValue)
        }
        return .init(data: data, isTemplate: true)
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
