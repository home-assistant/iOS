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
            case .circular: return "Circular"
            case .rectangular: return "Rectangular"
            case .inline: return "Inline"
            case .corner: return "Corner"
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
    /// Whether to show the state value as text (vs. icon-only).
    public var showValue: Bool

    // Custom-template kind
    public var customTextTemplate: String?
    public var customGaugeTemplate: String?

    public var sortOrder: Int

    public enum CodingKeys: String, CodingKey {
        case id, serverId, widgetFamily, kind, name
        case entityId, entityDisplayName, iconName, iconColor
        case gaugeAttribute, gaugeMin, gaugeMax, showValue
        case customTextTemplate, customGaugeTemplate, sortOrder
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
        sortOrder: Int = 0
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
    }

    public var displayName: String {
        name ?? entityDisplayName ?? entityId ?? "Complication"
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
}
