import AppIntents
import Foundation
import HAKit
import Shared

/// One entity's live state. Transient because it describes a moment rather than a resolvable entity.
@available(macOS 13.0, *)
struct HAEntityStateAppEntity: TransientAppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: .init("app_intents.entity_state.entity.name", defaultValue: "Entity State")
    )

    @Property(title: .init("app_intents.entity.property.name", defaultValue: "Name"))
    var name: String

    @Property(title: .init("app_intents.entity.property.entity_id", defaultValue: "Entity ID"))
    var entityId: String

    @Property(title: .init("app_intents.entity_state.domain.title", defaultValue: "Domain"))
    var domain: String

    /// The raw state string Home Assistant reports (`on`, `23.5`, `playing`), for branching.
    @Property(title: .init("app_intents.entity_state.state.title", defaultValue: "State"))
    var state: String

    /// The state the way the frontend shows it: localized, with the unit and display precision.
    @Property(title: .init("app_intents.entity_state.formatted_state.title", defaultValue: "Formatted state"))
    var formattedState: String

    @Property(title: .init("app_intents.entity_state.unit.title", defaultValue: "Unit of measurement"))
    var unitOfMeasurement: String?

    @Property(title: .init("app_intents.entity_state.device_class.title", defaultValue: "Device class"))
    var deviceClass: String?

    /// Whether the frontend would render this state as active (on, open, home, playing, …).
    @Property(title: .init("app_intents.entity_state.is_active.title", defaultValue: "Is active"))
    var isActive: Bool

    @Property(title: .init("app_intents.entity.property.area", defaultValue: "Area"))
    var areaName: String?

    @Property(title: .init("app_intents.entity.property.floor", defaultValue: "Floor"))
    var floorName: String?

    @Property(title: .init("app_intents.entity.property.device", defaultValue: "Device"))
    var deviceName: String?

    @Property(title: .init("app_intents.entity.property.server", defaultValue: "Server"))
    var serverName: String

    @Property(title: .init("app_intents.entity_state.last_changed.title", defaultValue: "Last changed"))
    var lastChanged: Date

    @Property(title: .init("app_intents.entity_state.last_updated.title", defaultValue: "Last updated"))
    var lastUpdated: Date

    /// Every attribute, as a JSON object, for Shortcuts to pick apart with "Get Dictionary Value".
    @Property(title: .init("app_intents.entity_state.attributes.title", defaultValue: "Attributes (JSON)"))
    var attributes: String

    /// The server-side icon name (`mdi:lightbulb`), or an SF Symbol name when the entity has none.
    var iconName: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(formattedState)",
            image: Self.image(iconName: iconName)
        )
    }

    init() {
        // Assigned first: a `@Property` setter goes through `self`, which must be fully initialized.
        self.iconName = ""
        self.name = ""
        self.entityId = ""
        self.domain = ""
        self.state = ""
        self.formattedState = ""
        self.isActive = false
        self.serverName = ""
        self.lastChanged = Date()
        self.lastUpdated = Date()
        self.attributes = "{}"
    }

    init(entity: HAAppEntityAppIntentEntity, state liveState: HAEntity) {
        self.init()
        self.name = entity.displayString
        self.entityId = liveState.entityId
        self.domain = liveState.domain
        self.state = liveState.state
        self.formattedState = Self.formattedState(for: liveState, serverId: entity.serverId)
        self.unitOfMeasurement = liveState.attributes.dictionary["unit_of_measurement"] as? String
        self.deviceClass = liveState.attributes.dictionary["device_class"] as? String
        self.isActive = EntityStateActive.isActive(domain: liveState.domain, state: liveState.state)
        // Queries pad missing context with ""; a property Siri reads should be absent instead.
        self.areaName = entity.areaName?.nilIfEmpty
        self.floorName = entity.floorName?.nilIfEmpty
        self.deviceName = entity.deviceName?.nilIfEmpty
        self.serverName = entity.serverName
        self.lastChanged = liveState.lastChanged
        self.lastUpdated = liveState.lastUpdated
        self.attributes = Self.attributesJSON(liveState.attributes.dictionary)
        self.iconName = entity.iconName
    }

    /// Formats the state as the frontend does, falling back to the plain localized state.
    static func formattedState(for entity: HAEntity, serverId: String?) -> String {
        if let domain = Domain(rawValue: entity.domain) {
            return domain.contextualStateDescription(for: entity, serverId: serverId)
        }
        return entity.localizedState.leadingCapitalized
    }

    /// Sorted keys so two reads of an unchanged entity compare equal in a Shortcut.
    static func attributesJSON(_ attributes: [String: Any]) -> String {
        guard JSONSerialization.isValidJSONObject(attributes),
              let data = try? JSONSerialization.data(withJSONObject: attributes, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    private static func image(iconName: String) -> DisplayRepresentation.Image {
        if let data = MaterialDesignIcons.pngData(forServersideValue: iconName) {
            return .init(data: data, isTemplate: true)
        }
        return .init(systemName: iconName)
    }
}
