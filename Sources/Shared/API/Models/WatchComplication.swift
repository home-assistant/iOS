import Foundation
import GRDB
import UIKit

/// A legacy (ClockKit-era) watch complication configuration.
///
/// Historically a Realm `Object` synced to the watch via ObjectMapper and rendered through ClockKit.
/// The watch now renders complications through WidgetKit (`WatchWidgets`), and the app is moving off
/// Realm, so this is a GRDB record. The shape is preserved verbatim (family + template + a free-form
/// `Data` JSON blob) so existing user complications keep working; new complications use
/// `WatchComplicationConfig` instead. Legacy complications are only editable under the "Legacy" section.
public struct WatchComplication: Codable, FetchableRecord, PersistableRecord, Equatable {
    public static var databaseTableName: String { GRDBDatabaseTable.watchComplication.rawValue }

    /// Posted after a legacy complication is created/edited/deleted so list views can refresh.
    public static let didChangeNotification = Notification.Name("watchComplicationsDidChange")

    public var identifier: String = UUID().uuidString
    public var serverIdentifier: String?

    /// Persisted raw value for `Family`. Column name kept as `rawFamily` for parity with the old model.
    public var rawFamily: String = ""
    /// Persisted raw value for `Template`.
    public var rawTemplate: String = ""
    /// The free-form configuration blob (text areas, gauge, ring, icon, rendered values), stored as JSON
    /// text. Was a binary `Data` column under Realm; JSON text is equivalent and easier to inspect.
    public var complicationData: String?
    public var createdAt: Date = Date()
    public var name: String?
    public var isPublic: Bool = true

    public enum CodingKeys: String, CodingKey {
        case identifier
        case serverIdentifier
        case rawFamily
        case rawTemplate
        case complicationData
        case createdAt
        case name
        case isPublic
    }

    public init(
        identifier: String = UUID().uuidString,
        serverIdentifier: String? = nil,
        family: ComplicationGroupMember = .modularSmall,
        template: ComplicationTemplate? = nil,
        data: [String: Any] = [:],
        createdAt: Date = Date(),
        name: String? = nil,
        isPublic: Bool = true
    ) {
        self.identifier = identifier
        self.serverIdentifier = serverIdentifier
        self.rawFamily = family.rawValue
        self.rawTemplate = (template ?? family.templates.first!).rawValue
        self.createdAt = createdAt
        self.name = name
        self.isPublic = isPublic
        Data = data
    }

    // MARK: - Typed accessors (not persisted directly)

    public var Family: ComplicationGroupMember {
        get { ComplicationGroupMember(rawValue: rawFamily) ?? .modularSmall }
        set { rawFamily = newValue.rawValue }
    }

    public var Template: ComplicationTemplate {
        get { ComplicationTemplate(rawValue: rawTemplate) ?? Family.templates.first! }
        set { rawTemplate = newValue.rawValue }
    }

    public var Data: [String: Any] {
        get {
            guard let complicationData, let data = complicationData.data(using: .utf8) else {
                return [:]
            }
            return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        }
        set {
            guard let data = try? JSONSerialization.data(withJSONObject: newValue),
                  let string = String(data: data, encoding: .utf8) else {
                complicationData = nil
                return
            }
            complicationData = string
        }
    }

    public var displayName: String {
        name ?? Template.style
    }

    // MARK: - Rendered values

    enum RenderedValueType: Hashable {
        case textArea(String)
        case gauge
        case ring

        init?(stringValue: String) {
            let values = stringValue.components(separatedBy: ",")
            guard values.count >= 1 else { return nil }
            switch values[0] {
            case "textArea" where values.count >= 2:
                self = .textArea(values[1])
            case "gauge":
                self = .gauge
            case "ring":
                self = .ring
            default:
                return nil
            }
        }

        var stringValue: String {
            switch self {
            case let .textArea(value): return "textArea,\(value)"
            case .gauge: return "gauge"
            case .ring: return "ring"
            }
        }
    }

    func renderedValues() -> [RenderedValueType: Any] {
        (Data["rendered"] as? [String: Any] ?? [:])
            .compactMapKeys(RenderedValueType.init(stringValue:))
    }

    mutating func updateRawRendered(from response: [String: Any]) {
        var data = Data
        data["rendered"] = response
        Data = data
    }

    func rawRendered() -> [String: String] {
        var renders = [RenderedValueType: String]()

        if let textAreas = Data["textAreas"] as? [String: [String: Any]], textAreas.isEmpty == false {
            let toAdd = textAreas.compactMapValues { $0["text"] as? String }
                .filter { $1.containsJinjaTemplate }
                .mapKeys { RenderedValueType.textArea($0) }
            renders.merge(toAdd, uniquingKeysWith: { a, _ in a })
        }

        if let gaugeDict = Data["gauge"] as? [String: String],
           let gauge = gaugeDict["gauge"], gauge.containsJinjaTemplate {
            renders[.gauge] = gauge
        }

        if let ringDict = Data["ring"] as? [String: String],
           let ringValue = ringDict["ring_value"], ringValue.containsJinjaTemplate {
            renders[.ring] = ringValue
        }

        return renders.mapKeys { $0.stringValue }
    }

    public static func percentileNumber(from value: Any) -> Float? {
        switch value {
        case let value as String:
            // a bit more forgiving than Float(_:)
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            for locale in [
                // in HA prior to 0.117 (which returns floats), the return type of a float is a string in templates
                // but it's a non-locale-aware string, so we need to parse `0.33` even if the locale expects `0,33`
                Locale(identifier: "en_US_POSIX"),
                // but since it's free-form text, the user may also have typed `0,33` expecting it to work
                Locale.current,
            ] {
                formatter.locale = locale
                if let value = formatter.number(from: value)?.floatValue {
                    return value
                }
            }
            return nil
        case let value as Int:
            return Float(value)
        case let value as Double:
            return Float(value)
        case let value as Float:
            return value
        default:
            Current.Log.info("unsure how to float-ify \(type(of: value)), trying as a string")
            return percentileNumber(from: String(describing: value))
        }
    }

    // MARK: - Queries

    public static func all() throws -> [WatchComplication] {
        try Current.database().read { db in
            try WatchComplication.order(Column(CodingKeys.createdAt.rawValue)).fetchAll(db)
        }
    }

    public static func all(forServerIdentifier serverIdentifier: String) throws -> [WatchComplication] {
        try Current.database().read { db in
            try WatchComplication
                .filter(Column(CodingKeys.serverIdentifier.rawValue) == serverIdentifier)
                .fetchAll(db)
        }
    }

    /// Insert or update this complication.
    public func save() throws {
        try Current.database().write { db in
            try save(db)
        }
    }

    public func delete() throws {
        _ = try Current.database().write { db in
            try WatchComplication.deleteOne(db, key: identifier)
        }
    }

    /// Replace all stored complications (used on the watch when a fresh set arrives).
    public static func replaceAll(_ complications: [WatchComplication]) throws {
        _ = try Current.database().write { db in
            try WatchComplication.deleteAll(db)
            for complication in complications { try complication.insert(db) }
        }
    }

    /// Delete complications whose server no longer exists (rows with no server are kept).
    public static func deleteOrphans(keepingServerIdentifiers serverIdentifiers: [String]) throws {
        _ = try Current.database().write { db in
            try WatchComplication
                .filter(!serverIdentifiers.contains(Column(CodingKeys.serverIdentifier.rawValue)))
                .deleteAll(db)
        }
    }
}

/// A modern watch complication built from a Home Assistant entity (auto-designed) or a custom
/// template. Unlike `WatchComplication`, it targets one of the four WidgetKit accessory families and
/// is rendered by the watch itself: entity icon/name are denormalized here at build time, and the
/// watch fetches only the live state over REST. Persisted in GRDB and synced to the watch.
public struct WatchComplicationConfig: Codable, FetchableRecord, PersistableRecord, Equatable, Identifiable {
    public static var databaseTableName: String { GRDBDatabaseTable.watchComplicationConfig.rawValue }

    /// Posted after a config is created/edited/deleted so list views can refresh.
    public static let didChangeNotification = Notification.Name("watchComplicationConfigsDidChange")

    public enum Kind: String, Codable, CaseIterable { case entity, customTemplate }

    /// The four modern WidgetKit accessory families.
    public enum Family: String, Codable, CaseIterable, Identifiable {
        case circular
        case rectangular
        case inline
        case corner
        public var id: String { rawValue }

        public var title: String {
            switch self {
            case .circular: return L10n.Watch.Complications.Family.circular
            case .rectangular: return L10n.Watch.Complications.Family.rectangular
            case .inline: return L10n.Watch.Complications.Family.inline
            case .corner: return L10n.Watch.Complications.Family.corner
            }
        }
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
    public var gaugeMin: Double?
    public var gaugeMax: Double?
    /// Whether to show the state value as text (vs. icon-only). Base default; can be overridden per size.
    public var showValue: Bool

    // Custom-template kind
    public var customTextTemplate: String?
    public var customGaugeTemplate: String?

    public var sortOrder: Int

    /// Per-family customization overrides, keyed by `Family.rawValue`. Any field left nil falls back to
    /// the base value, so one config works in every size yet can be tuned per size. Optional/nullable so
    /// rows created before this column migrate cleanly.
    public var families: [String: FamilyOptions]?

    public struct FamilyOptions: Codable, Equatable {
        public var showValue: Bool?
        public var showGauge: Bool?
        public var gaugeMin: Double?
        public var gaugeMax: Double?
        public var gaugeAttribute: String?
        public var tint: String?

        public init(
            showValue: Bool? = nil,
            showGauge: Bool? = nil,
            gaugeMin: Double? = nil,
            gaugeMax: Double? = nil,
            gaugeAttribute: String? = nil,
            tint: String? = nil
        ) {
            self.showValue = showValue
            self.showGauge = showGauge
            self.gaugeMin = gaugeMin
            self.gaugeMax = gaugeMax
            self.gaugeAttribute = gaugeAttribute
            self.tint = tint
        }
    }

    public enum CodingKeys: String, CodingKey {
        case id, serverId, widgetFamily, kind, name
        case entityId, entityDisplayName, iconName, iconColor
        case gaugeAttribute, gaugeMin, gaugeMax, showValue
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
        gaugeMin: Double? = nil,
        gaugeMax: Double? = nil,
        showValue: Bool = true,
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
        self.gaugeMin = gaugeMin
        self.gaugeMax = gaugeMax
        self.showValue = showValue
        self.customTextTemplate = customTextTemplate
        self.customGaugeTemplate = customGaugeTemplate
        self.sortOrder = sortOrder
        self.families = families
    }

    public var displayName: String {
        name ?? entityDisplayName ?? entityId ?? "Complication"
    }

    // MARK: - Per-family resolution (override → base fallback)

    public func showsValue(for family: Family) -> Bool {
        families?[family.rawValue]?.showValue ?? showValue
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

    public func tint(for family: Family) -> String? {
        families?[family.rawValue]?.tint ?? iconColor
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

    public static func all() throws -> [WatchComplicationConfig] {
        try Current.database().read { db in
            try WatchComplicationConfig.order(Column(CodingKeys.sortOrder.rawValue)).fetchAll(db)
        }
    }

    public func save() throws {
        try Current.database().write { db in try save(db) }
    }

    public func delete() throws {
        _ = try Current.database().write { db in
            try WatchComplicationConfig.deleteOne(db, key: id)
        }
    }

    /// Replace all stored configs (used on the watch when a fresh set arrives).
    public static func replaceAll(_ configs: [WatchComplicationConfig]) throws {
        _ = try Current.database().write { db in
            try WatchComplicationConfig.deleteAll(db)
            for config in configs { try config.insert(db) }
        }
    }

    /// Delete configs whose server no longer exists.
    public static func deleteOrphans(keepingServerIds serverIds: [String]) throws {
        _ = try Current.database().write { db in
            try WatchComplicationConfig
                .filter(!serverIds.contains(Column(CodingKeys.serverId.rawValue)))
                .deleteAll(db)
        }
    }
}
