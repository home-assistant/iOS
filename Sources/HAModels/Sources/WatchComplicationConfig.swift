import Foundation
import GRDB

/// A modern watch complication built from a Home Assistant entity (auto-designed) or a custom
/// template. Unlike `WatchComplication`, it targets one of the four WidgetKit accessory families and
/// is rendered by the watch itself: entity icon/name are denormalized here at build time, and the
/// watch fetches only the live state over REST. Persisted in GRDB and synced to the watch.
///
/// This is a pure, extension-safe model (Foundation + GRDB only) so a watch widget extension can
/// decode and render it without linking the full app. UI-only helpers (localized family/style titles)
/// and the `Current.database()`-backed queries live in extensions in the `Shared` module.
public struct WatchComplicationConfig: Codable, FetchableRecord, PersistableRecord, Equatable, Identifiable {
    public static var databaseTableName: String { GRDBDatabaseTable.watchComplicationConfig.rawValue }

    /// Posted after a config is created/edited/deleted so list views can refresh.
    public static let didChangeNotification = Notification.Name("watchComplicationConfigsDidChange")

    public enum Kind: String, Codable, CaseIterable { case entity, customTemplate }

    /// How a gauge/ring is drawn for a circular complication. `open` is the ~270° arc gauge
    /// (`.accessoryCircular`) that can show min/max labels; `capacity` is the full closed ring
    /// (`.accessoryCircularCapacity`). Other families ignore this and draw their family-appropriate gauge.
    public enum GaugeStyle: String, Codable, CaseIterable, Identifiable {
        case open
        case capacity
        public var id: String { rawValue }
    }

    /// The four modern WidgetKit accessory families.
    public enum Family: String, Codable, CaseIterable, Identifiable {
        case circular
        case rectangular
        case inline
        case corner
        public var id: String { rawValue }
    }

    public var id: String
    public var serverId: String
    public var widgetFamily: Family
    public var kind: Kind
    public var name: String?

    // Entity kind (denormalized so the watch needs no entity registry)
    public var entityId: String?
    public var entityDisplayName: String?
    public var iconName: String?
    public var iconColor: String?
    /// Attribute used for a gauge/ring value; `nil` uses the entity state. Only meaningful when numeric.
    public var gaugeAttribute: String?
    /// Attribute whose value is shown as the complication's text (and used as the gauge basis when no
    /// dedicated `gaugeAttribute` is set); `nil` shows the entity state. Global — the value text is
    /// shared across sizes.
    public var valueAttribute: String?
    /// Number of decimal places for a numeric value; `nil` follows Home Assistant's display precision.
    /// Global — the value text is shared across sizes.
    public var valuePrecision: Int?
    /// A custom unit shown after the value; `nil`/empty resolves the unit automatically (the state's
    /// unit_of_measurement, or an attribute's resolved unit). Global — the value text is shared across sizes.
    public var unitOverride: String?
    public var gaugeMin: Double?
    public var gaugeMax: Double?
    /// Whether to show the state value as text (vs. icon-only). Base default; can be overridden per size.
    public var showValue: Bool
    /// Whether to append the entity's unit of measurement to the value. Nullable so pre-existing rows
    /// (NULL) default to visible; see `showsUnit()`.
    public var showUnit: Bool?
    /// Whether the complication is shown while the display is dimmed (wrist down / always-on). Nullable
    /// so pre-existing rows (NULL) default to visible; see `showsWhenInactive()`.
    public var showWhenInactive: Bool?
    /// Whether the minimum / maximum labels are shown alongside a progress bar / open gauge. Base default
    /// (can be overridden per size); nullable so pre-existing rows (NULL) default to visible.
    public var showMin: Bool?
    public var showMax: Bool?

    // Custom-template kind
    public var customTextTemplate: String?
    public var customGaugeTemplate: String?

    public var sortOrder: Int

    /// Per-family customization overrides, keyed by `Family.rawValue`. Any field left nil falls back to
    /// the base value, so one config works in every size yet can be tuned per size. Optional/nullable so
    /// rows created before this column migrate cleanly.
    public var families: [String: FamilyOptions]?

    public struct FamilyOptions: Codable, Equatable {
        public var showName: Bool?
        public var showValue: Bool?
        public var showIcon: Bool?
        public var showGauge: Bool?
        /// Per-size override for whether the minimum / maximum labels are shown alongside a progress bar /
        /// open gauge; nil falls back to the base `showMin` / `showMax`.
        public var showMin: Bool?
        public var showMax: Bool?
        public var gaugeMin: Double?
        public var gaugeMax: Double?
        public var gaugeAttribute: String?
        public var tint: String?
        /// Raw value of `GaugeStyle`; nil defaults to `.open`. Only meaningful for circular.
        public var gaugeStyle: String?
        /// Hex color for the value/text; nil uses the default (primary) color.
        public var textColor: String?

        public init(
            showName: Bool? = nil,
            showValue: Bool? = nil,
            showIcon: Bool? = nil,
            showGauge: Bool? = nil,
            showMin: Bool? = nil,
            showMax: Bool? = nil,
            gaugeMin: Double? = nil,
            gaugeMax: Double? = nil,
            gaugeAttribute: String? = nil,
            tint: String? = nil,
            gaugeStyle: String? = nil,
            textColor: String? = nil
        ) {
            self.showName = showName
            self.showValue = showValue
            self.showIcon = showIcon
            self.showGauge = showGauge
            self.showMin = showMin
            self.showMax = showMax
            self.gaugeMin = gaugeMin
            self.gaugeMax = gaugeMax
            self.gaugeAttribute = gaugeAttribute
            self.tint = tint
            self.gaugeStyle = gaugeStyle
            self.textColor = textColor
        }
    }

    public enum CodingKeys: String, CodingKey {
        case id, serverId, widgetFamily, kind, name
        case entityId, entityDisplayName, iconName, iconColor
        case gaugeAttribute, valueAttribute, valuePrecision, unitOverride, gaugeMin, gaugeMax
        case showValue, showUnit, showWhenInactive, showMin, showMax
        case customTextTemplate, customGaugeTemplate, sortOrder, families
    }

    public init(
        id: String = UUID().uuidString,
        serverId: String,
        widgetFamily: Family = .circular,
        kind: Kind = .entity,
        name: String? = nil,
        entityId: String? = nil,
        entityDisplayName: String? = nil,
        iconName: String? = nil,
        iconColor: String? = nil,
        gaugeAttribute: String? = nil,
        valueAttribute: String? = nil,
        valuePrecision: Int? = nil,
        unitOverride: String? = nil,
        gaugeMin: Double? = nil,
        gaugeMax: Double? = nil,
        showValue: Bool = true,
        showUnit: Bool? = nil,
        showWhenInactive: Bool? = nil,
        showMin: Bool? = nil,
        showMax: Bool? = nil,
        customTextTemplate: String? = nil,
        customGaugeTemplate: String? = nil,
        sortOrder: Int = 0,
        families: [String: FamilyOptions]? = nil
    ) {
        self.id = id
        self.serverId = serverId
        self.widgetFamily = widgetFamily
        self.kind = kind
        self.name = name
        self.entityId = entityId
        self.entityDisplayName = entityDisplayName
        self.iconName = iconName
        self.iconColor = iconColor
        self.gaugeAttribute = gaugeAttribute
        self.valueAttribute = valueAttribute
        self.valuePrecision = valuePrecision
        self.unitOverride = unitOverride
        self.gaugeMin = gaugeMin
        self.gaugeMax = gaugeMax
        self.showValue = showValue
        self.showUnit = showUnit
        self.showWhenInactive = showWhenInactive
        self.showMin = showMin
        self.showMax = showMax
        self.customTextTemplate = customTextTemplate
        self.customGaugeTemplate = customGaugeTemplate
        self.sortOrder = sortOrder
        self.families = families
    }

    public var displayName: String {
        name ?? entityDisplayName ?? entityId ?? "Complication"
    }

    // MARK: - Per-family resolution (override → family default)

    /// Whether the complication's name is shown for this family. Circular is too small for a name, so
    /// it defaults off; the other families default on.
    public func showsName(for family: Family) -> Bool {
        families?[family.rawValue]?.showName ?? (family != .circular)
    }

    public func showsValue(for family: Family) -> Bool {
        families?[family.rawValue]?.showValue ?? showValue
    }

    /// Whether the icon is shown for this family. Rectangular always leads with the icon; the compact
    /// families (circular/inline/corner) default off but can opt in.
    public func showsIcon(for family: Family) -> Bool {
        families?[family.rawValue]?.showIcon ?? (family == .rectangular)
    }

    /// Whether the minimum label is shown next to a progress bar / open gauge: per-size override, then
    /// the base value, then visible by default (so pre-existing configs are unchanged).
    public func showsMin(for family: Family) -> Bool {
        families?[family.rawValue]?.showMin ?? showMin ?? true
    }

    /// Whether the maximum label is shown next to a progress bar / open gauge: per-size override, then
    /// the base value, then visible by default (so pre-existing configs are unchanged).
    public func showsMax(for family: Family) -> Bool {
        families?[family.rawValue]?.showMax ?? showMax ?? true
    }

    /// Whether a gauge/ring should be drawn for this family.
    public func showsGauge(for family: Family) -> Bool {
        if let override = families?[family.rawValue]?.showGauge { return override }
        // Base default: a gauge is shown when a numeric range is configured.
        return gaugeMin != nil && gaugeMax != nil
    }

    /// The resolved gauge range for this family, or nil when no gauge should be drawn.
    public func gaugeRange(for family: Family) -> (min: Double, max: Double)? {
        guard showsGauge(for: family) else { return nil }
        let options = families?[family.rawValue]
        if let minValue = options?.gaugeMin, let maxValue = options?.gaugeMax, maxValue > minValue {
            return (minValue, maxValue)
        }
        if let minValue = gaugeMin, let maxValue = gaugeMax, maxValue > minValue {
            return (minValue, maxValue)
        }
        return nil
    }

    public func gaugeAttribute(for family: Family) -> String? {
        families?[family.rawValue]?.gaugeAttribute ?? gaugeAttribute
    }

    /// Whether the entity's unit of measurement is appended to the value. Global (the value text is
    /// shared across sizes); defaults to visible when unset.
    public func showsUnit() -> Bool {
        showUnit ?? true
    }

    /// Resolves the unit for an attribute value the way the Home Assistant frontend does. The state's
    /// `unit_of_measurement` intentionally NEVER applies to an attribute — that only describes the state.
    /// Order: a sibling `<attribute>_unit` attribute (the weather pattern: `temperature` →
    /// `temperature_unit`, `pressure` → `pressure_unit`, …), then a small domain→attribute→unit map for
    /// well-known percentages / kelvin, else nil (show the raw value with no unit).
    public static func attributeUnit(
        attribute: String,
        attributes: [String: Any],
        domain: String?
    ) -> String? {
        if let sibling = attributes["\(attribute)_unit"] as? String, !sibling.isEmpty {
            return sibling
        }
        return domainAttributeUnits[domain ?? ""]?[attribute]
    }

    /// Well-known attribute units, mirroring the frontend's `DOMAIN_ATTRIBUTES_UNITS`. Only attributes
    /// whose scale is unambiguous (0–100 percentages, kelvin) are included; anything else resolves to no
    /// unit rather than risk a wrong one.
    private static let domainAttributeUnits: [String: [String: String]] = [
        "climate": ["humidity": "%", "current_humidity": "%"],
        "cover": ["current_position": "%", "current_tilt_position": "%"],
        "fan": ["percentage": "%"],
        "humidifier": ["humidity": "%", "current_humidity": "%"],
        "light": ["color_temp_kelvin": "K"],
        "vacuum": ["battery_level": "%"],
        "valve": ["current_position": "%"],
        "weather": ["humidity": "%", "cloud_coverage": "%"],
    ]

    /// Whether the complication is shown while the display is dimmed (always-on / wrist down); defaults
    /// to visible when unset.
    public func showsWhenInactive() -> Bool {
        showWhenInactive ?? true
    }

    /// The gauge style for a family (circular only); defaults to `.open`.
    public func gaugeStyle(for family: Family) -> GaugeStyle {
        families?[family.rawValue]?.gaugeStyle.flatMap(GaugeStyle.init(rawValue:)) ?? .open
    }

    public func tint(for family: Family) -> String? {
        families?[family.rawValue]?.tint ?? iconColor
    }

    /// The value/text color for a family, or nil to use the default (primary) color.
    public func textColor(for family: Family) -> String? {
        families?[family.rawValue]?.textColor
    }

    /// Mutable access to a family's options, creating an empty set if none exists yet.
    public func options(for family: Family) -> FamilyOptions {
        families?[family.rawValue] ?? FamilyOptions()
    }

    public mutating func setOptions(_ options: FamilyOptions, for family: Family) {
        var resolved = families ?? [:]
        resolved[family.rawValue] = options
        families = resolved
    }
}
