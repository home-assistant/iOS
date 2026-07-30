import Foundation
import HAKit

/// The read-only facts the watch shows for a display-only item (a sensor): its current state, when
/// the server last changed/updated it, and the attributes worth reading on a small screen.
///
/// Built from the very same `HAEntity` the row's REST poller already fetches — no extra request —
/// and deliberately free of any UI so the formatting is unit testable.
public struct WatchEntityDetails: Equatable {
    /// One attribute row: the raw key (identity), a humanized label, and a display value.
    public struct Attribute: Equatable, Identifiable {
        public let id: String
        public let name: String
        public let value: String

        public init(id: String, name: String, value: String) {
            self.id = id
            self.name = name
            self.value = value
        }
    }

    public let entityId: String
    public let name: String
    /// Localized state, with the unit of measurement appended when the entity has one.
    public let state: String
    /// Humanized device class (e.g. "Temperature", "Signal strength") when the entity declares a
    /// known one. Home Assistant has no translations for device class names, so this is the raw
    /// identifier made readable.
    public let deviceClass: String?
    public let lastChanged: Date
    public let lastUpdated: Date
    public let attributes: [Attribute]

    /// Attributes that are either rendered elsewhere on the screen (name, unit, device class) or
    /// carry nothing a person can read (icons, feature bitmasks).
    private static let hiddenAttributeKeys: Set<String> = [
        "friendly_name",
        "icon",
        "entity_picture",
        "unit_of_measurement",
        "device_class",
        "supported_features",
    ]

    public init(entity: HAEntity) {
        let domain = Domain(rawValue: entity.domain)
        self.entityId = entity.entityId
        self.name = entity.attributes.friendlyName ?? entity.entityId
        self.state = domain?.contextualStateDescription(for: entity) ?? entity.state.leadingCapitalized
        // Read from the raw attribute rather than the `DeviceClass` enum, so a device class this app
        // doesn't know about is still shown instead of dropped (the key itself is hidden below).
        self.deviceClass = (entity.attributes.dictionary["device_class"] as? String)
            .map { Self.displayName(for: $0) }
        self.lastChanged = entity.lastChanged
        self.lastUpdated = entity.lastUpdated
        self.attributes = entity.attributes.dictionary
            .filter { !Self.hiddenAttributeKeys.contains($0.key) }
            .compactMap { key, value in
                guard let value = Self.displayValue(for: value) else { return nil }
                return Attribute(id: key, name: Self.displayName(for: key), value: value)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// "battery_level" → "Battery level".
    private static func displayName(for key: String) -> String {
        key.replacingOccurrences(of: "_", with: " ").leadingCapitalized
    }

    /// Renders an attribute value as a single readable line, or nil when there is nothing to show
    /// (null, or an empty string/collection).
    private static func displayValue(for value: Any) -> String? {
        switch value {
        case is NSNull:
            return nil
        case let number as NSNumber:
            // JSON booleans arrive as NSNumber too, and `as? Bool` would also match 0/1 integers —
            // so a sensor reading of 1 would read "Yes". Check the underlying type instead.
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return number.boolValue ? L10n.yesLabel : L10n.noLabel
            }
            return number.stringValue
        case let string as String:
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        case let array as [Any]:
            let values = array.compactMap { displayValue(for: $0) }
            return values.isEmpty ? nil : values.joined(separator: ", ")
        case let dictionary as [String: Any]:
            let values = dictionary.keys.sorted().compactMap { key -> String? in
                guard let value = dictionary[key], let value = displayValue(for: value) else { return nil }
                return "\(displayName(for: key)): \(value)"
            }
            return values.isEmpty ? nil : values.joined(separator: ", ")
        default:
            return String(describing: value)
        }
    }
}
