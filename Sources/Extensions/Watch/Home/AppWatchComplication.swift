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

    enum CodingKeys: String, CodingKey {
        case identifier
        case serverIdentifier
        case rawFamily
        case rawTemplate
        case complicationData
        case createdAt
        case name
    }

    public init(
        identifier: String,
        serverIdentifier: String?,
        rawFamily: String,
        rawTemplate: String,
        complicationData: [String: Any],
        createdAt: Date,
        name: String?
    ) {
        self.identifier = identifier
        self.serverIdentifier = serverIdentifier
        self.rawFamily = rawFamily
        self.rawTemplate = rawTemplate
        self.complicationData = complicationData
        self.createdAt = createdAt
        self.name = name
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
            name: name
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
