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
    public var createdAt: Date = .init()
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
        self.Data = data
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
            for complication in complications {
                try complication.insert(db)
            }
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

// MARK: - WatchComplicationConfig UI titles + queries

//
// `WatchComplicationConfig` itself is a pure, extension-safe model in the `HAModels` package
// (Foundation + GRDB only). The localized family/style titles and the `Current.database()`-backed
// queries stay here in `Shared`, which has access to `L10n` and `Current`.

public extension WatchComplicationConfig.GaugeStyle {
    var title: String {
        switch self {
        case .open: return L10n.Watch.Complications.GaugeStyle.open
        case .capacity: return L10n.Watch.Complications.GaugeStyle.capacity
        }
    }
}

public extension WatchComplicationConfig.Family {
    var title: String {
        switch self {
        case .circular: return L10n.Watch.Complications.Family.circular
        case .rectangular: return L10n.Watch.Complications.Family.rectangular
        case .inline: return L10n.Watch.Complications.Family.inline
        case .corner: return L10n.Watch.Complications.Family.corner
        }
    }
}

public extension WatchComplicationConfig {
    static func all() throws -> [WatchComplicationConfig] {
        try Current.database().read { db in
            try WatchComplicationConfig.order(Column(CodingKeys.sortOrder.rawValue)).fetchAll(db)
        }
    }

    func save() throws {
        try Current.database().write { db in try save(db) }
    }

    func delete() throws {
        _ = try Current.database().write { db in
            try WatchComplicationConfig.deleteOne(db, key: id)
        }
    }

    /// Replace all stored configs (used on the watch when a fresh set arrives).
    static func replaceAll(_ configs: [WatchComplicationConfig]) throws {
        _ = try Current.database().write { db in
            try WatchComplicationConfig.deleteAll(db)
            for config in configs {
                try config.insert(db)
            }
        }
    }

    /// Delete configs whose server no longer exists.
    static func deleteOrphans(keepingServerIds serverIds: [String]) throws {
        _ = try Current.database().write { db in
            try WatchComplicationConfig
                .filter(!serverIds.contains(Column(CodingKeys.serverId.rawValue)))
                .deleteAll(db)
        }
    }
}
