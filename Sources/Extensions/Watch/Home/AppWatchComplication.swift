import Foundation
import GRDB

/// AppWatchComplication represents a complication stored in the watch's GRDB database
/// It stores the complete JSON data from the iPhone's Realm WatchComplication object
public struct AppWatchComplication: Codable {
    public var identifier: String
    public var serverIdentifier: String?
    public var rawFamily: String
    public var rawTemplate: String
    public var complicationData: [String: Any]
    public var createdAt: Date
    public var name: String?
    public var isPublic: Bool

    enum CodingKeys: String, CodingKey {
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
        identifier: String,
        serverIdentifier: String?,
        rawFamily: String,
        rawTemplate: String,
        complicationData: [String: Any],
        createdAt: Date,
        name: String?,
        isPublic: Bool = true
    ) {
        self.identifier = identifier
        self.serverIdentifier = serverIdentifier
        self.rawFamily = rawFamily
        self.rawTemplate = rawTemplate
        self.complicationData = complicationData
        self.createdAt = createdAt
        self.name = name
        self.isPublic = isPublic
    }

    // MARK: - Codable

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.identifier = try container.decode(String.self, forKey: .identifier)
        self.serverIdentifier = try container.decodeIfPresent(String.self, forKey: .serverIdentifier)
        self.rawFamily = try container.decode(String.self, forKey: .rawFamily)
        self.rawTemplate = try container.decode(String.self, forKey: .rawTemplate)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.isPublic = try container.decodeIfPresent(Bool.self, forKey: .isPublic) ?? true

        // Decode JSON string to dictionary
        let jsonString = try container.decode(String.self, forKey: .complicationData)
        if let data = jsonString.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            self.complicationData = json
        } else {
            self.complicationData = [:]
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(identifier, forKey: .identifier)
        try container.encodeIfPresent(serverIdentifier, forKey: .serverIdentifier)
        try container.encode(rawFamily, forKey: .rawFamily)
        try container.encode(rawTemplate, forKey: .rawTemplate)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encode(isPublic, forKey: .isPublic)

        // Encode dictionary to JSON string for database storage
        let data = try JSONSerialization.data(withJSONObject: complicationData, options: [])
        if let jsonString = String(data: data, encoding: .utf8) {
            try container.encode(jsonString, forKey: .complicationData)
        }
    }
}

// MARK: - GRDB Conformance

extension AppWatchComplication: FetchableRecord, PersistableRecord {
    public static var databaseTableName: String {
        GRDBDatabaseTable.appWatchComplication.rawValue
    }
}

// MARK: - Convenience Methods

public extension AppWatchComplication {
    /// Creates an AppWatchComplication from JSON data received from iPhone
    static func from(jsonData: Data) throws -> AppWatchComplication {
        guard let json = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] else {
            throw NSError(
                domain: "AppWatchComplication",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to deserialize JSON data"]
            )
        }

        guard let identifier = json["identifier"] as? String else {
            throw NSError(
                domain: "AppWatchComplication",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Missing identifier in JSON"]
            )
        }

        let serverIdentifier = json["serverIdentifier"] as? String
        let rawFamily = json["Family"] as? String ?? ""
        let rawTemplate = json["Template"] as? String ?? ""
        let name = json["name"] as? String
        let complicationData = json["Data"] as? [String: Any] ?? [:]
        let isPublic = json["IsPublic"] as? Bool ?? true

        // Parse CreatedAt date
        let createdAt: Date
        if let timestamp = json["CreatedAt"] as? TimeInterval {
            createdAt = Date(timeIntervalSince1970: timestamp)
        } else if let dateString = json["CreatedAt"] as? String {
            let formatter = ISO8601DateFormatter()
            createdAt = formatter.date(from: dateString) ?? Date()
        } else {
            createdAt = Date()
        }

        return AppWatchComplication(
            identifier: identifier,
            serverIdentifier: serverIdentifier,
            rawFamily: rawFamily,
            rawTemplate: rawTemplate,
            complicationData: complicationData,
            createdAt: createdAt,
            name: name,
            isPublic: isPublic
        )
    }

    /// Fetches all complications from the database
    static func fetchAll(from database: Database) throws -> [AppWatchComplication] {
        try AppWatchComplication.fetchAll(database)
    }

    /// Fetches a specific complication by identifier
    static func fetch(identifier: String, from database: Database) throws -> AppWatchComplication? {
        try AppWatchComplication
            .filter(Column(DatabaseTables.AppWatchComplication.identifier.rawValue) == identifier)
            .fetchOne(database)
    }

    /// Deletes all complications from the database
    static func deleteAll(from database: Database) throws {
        try AppWatchComplication.deleteAll(database)
    }
}

// MARK: - watchOS Complication Support

#if os(watchOS)
import ClockKit
import UIKit

public extension AppWatchComplication {
    /// Display name for the complication
    var displayName: String {
        name ?? template.style
    }

    /// The Family enum from rawFamily string
    var family: ComplicationGroupMember {
        ComplicationGroupMember(rawValue: rawFamily) ?? .modularSmall
    }

    /// The Template enum from rawTemplate string
    var template: ComplicationTemplate {
        ComplicationTemplate(rawValue: rawTemplate) ?? family.templates.first!
    }

    // MARK: - Rendered Values Support

    /// Enum representing different types of renderable values in a complication
    enum RenderedValueType: Hashable {
        case textArea(String)
        case gauge
        case ring

        init?(stringValue: String) {
            let values = stringValue.components(separatedBy: ",")

            guard values.count >= 1 else {
                return nil
            }

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

    /// Returns the rendered values dictionary from server template rendering
    func renderedValues() -> [RenderedValueType: Any] {
        (complicationData["rendered"] as? [String: Any] ?? [:])
            .compactMapKeys(RenderedValueType.init(stringValue:))
    }

    /// Updates the rendered values with response from server
    /// - Parameter response: Dictionary of rendered template values from webhook
    mutating func updateRenderedValues(from response: [String: Any]) {
        complicationData["rendered"] = response
    }

    /// Returns the raw unrendered template strings that need server-side rendering
    /// Used by webhook system to request template rendering from Home Assistant
    func rawRendered() -> [String: String] {
        var renders = [RenderedValueType: String]()

        if let textAreas = complicationData["textAreas"] as? [String: [String: Any]], textAreas.isEmpty == false {
            let toAdd = textAreas.compactMapValues { $0["text"] as? String }
                .filter { $1.containsJinjaTemplate } // Note: Requires String extension from Shared module
                .mapKeys { RenderedValueType.textArea($0) }
            renders.merge(toAdd, uniquingKeysWith: { a, _ in a })
        }

        if let gaugeDict = complicationData["gauge"] as? [String: String],
           let gauge = gaugeDict["gauge"], gauge.containsJinjaTemplate {
            renders[.gauge] = gauge
        }

        if let ringDict = complicationData["ring"] as? [String: String],
           let ringValue = ringDict["ring_value"], ringValue.containsJinjaTemplate {
            renders[.ring] = ringValue
        }

        return renders.mapKeys { $0.stringValue }
    }

    /// Complication descriptor for ClockKit
    var complicationDescriptor: CLKComplicationDescriptor {
        CLKComplicationDescriptor(
            identifier: identifier,
            displayName: displayName,
            supportedFamilies: [family.family]
        )
    }

    /// Generate CLKComplicationTemplate for display
    /// This delegates to the WatchComplication implementation temporarily
    /// TODO: Port template generation logic directly to AppWatchComplication
    func clkComplicationTemplate(family complicationFamily: CLKComplicationFamily) -> CLKComplicationTemplate? {
        // For now, convert to WatchComplication to use existing template logic
        // This is a temporary solution until we fully port the template generation
        guard let watchComplication = try? WatchComplication(JSON: [
            "identifier": identifier,
            "serverIdentifier": serverIdentifier as Any,
            "Family": rawFamily,
            "Template": rawTemplate,
            "Data": complicationData,
            "CreatedAt": createdAt.timeIntervalSince1970,
            "name": name as Any,
            "IsPublic": isPublic,
        ]) else {
            return nil
        }

        return watchComplication.CLKComplicationTemplate(family: complicationFamily)
    }
}

// MARK: - Dictionary Helpers

fileprivate extension Dictionary {
    func mapKeys<T: Hashable>(_ transform: (Key) -> T) -> [T: Value] {
        var result = [T: Value]()
        for (key, value) in self {
            result[transform(key)] = value
        }
        return result
    }

    func compactMapKeys<T: Hashable>(_ transform: (Key) -> T?) -> [T: Value] {
        var result = [T: Value]()
        for (key, value) in self {
            if let newKey = transform(key) {
                result[newKey] = value
            }
        }
        return result
    }
}
#endif
