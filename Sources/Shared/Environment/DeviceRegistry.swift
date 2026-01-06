import Foundation
import GRDB
import HAKit

public struct DeviceRegistryEntry: Codable, HADataDecodable {
    public let areaID: String?
    public let configurationURL: String?
    public let configEntries: [String]
    public let configEntriesSubentries: [String: [String?]]
    public let connections: [String]
    public let createdAt: Double
    public let disabledBy: String?
    public let entryType: String
    public let hwVersion: String?
    public let id: String
    public let identifiers: [[String]]
    public let labels: [String]
    public let manufacturer: String?
    public let model: String?
    public let modelID: String?
    public let modifiedAt: Double
    public let nameByUser: String?
    public let name: String?
    public let primaryConfigEntry: String?
    public let serialNumber: String?
    public let swVersion: String?
    public let viaDeviceID: String?

    public init(data: HAData) throws {
        self.areaID = try? data.decode("area_id")
        self.configurationURL = try? data.decode("configuration_url")
        self.configEntries = try data.decode("config_entries")
        self.configEntriesSubentries = try data.decode("config_entries_subentries")
        self.connections = try data.decode("connections")
        self.createdAt = try data.decode("created_at")
        self.disabledBy = try? data.decode("disabled_by")
        self.entryType = try data.decode("entry_type")
        self.hwVersion = try? data.decode("hw_version")
        self.id = try data.decode("id")
        self.identifiers = try data.decode("identifiers")
        self.labels = try data.decode("labels")
        self.manufacturer = try? data.decode("manufacturer")
        self.model = try? data.decode("model")
        self.modelID = try? data.decode("model_id")
        self.modifiedAt = try data.decode("modified_at")
        self.nameByUser = try? data.decode("name_by_user")
        self.name = try? data.decode("name")
        self.primaryConfigEntry = try? data.decode("primary_config_entry")
        self.serialNumber = try? data.decode("serial_number")
        self.swVersion = try? data.decode("sw_version")
        self.viaDeviceID = try? data.decode("via_device_id")
    }

    // Computed helpers
    var displayName: String {
        nameByUser ?? name ?? model ?? id
    }

    var isDisabled: Bool { disabledBy != nil }
}

// MARK: - Database Model

public struct AppDeviceRegistry: Codable, FetchableRecord, PersistableRecord {
    public let serverId: String

    // All DeviceRegistry fields
    public let areaID: String?
    public let configurationURL: String?
    public let configEntries: [String]
    public let configEntriesSubentries: [String: [String?]]
    public let connections: [String]
    public let createdAt: Double
    public let disabledBy: String?
    public let entryType: String
    public let hwVersion: String?
    public let deviceId: String
    public let identifiers: [[String]]
    public let labels: [String]
    public let manufacturer: String?
    public let model: String?
    public let modelID: String?
    public let modifiedAt: Double
    public let nameByUser: String?
    public let name: String?
    public let primaryConfigEntry: String?
    public let serialNumber: String?
    public let swVersion: String?
    public let viaDeviceID: String?

    public init(serverId: String, registry: DeviceRegistryEntry) {
        self.serverId = serverId

        // Copy all fields from DeviceRegistry
        self.areaID = registry.areaID
        self.configurationURL = registry.configurationURL
        self.configEntries = registry.configEntries
        self.configEntriesSubentries = registry.configEntriesSubentries
        self.connections = registry.connections
        self.createdAt = registry.createdAt
        self.disabledBy = registry.disabledBy
        self.entryType = registry.entryType
        self.hwVersion = registry.hwVersion
        self.deviceId = registry.id
        self.identifiers = registry.identifiers
        self.labels = registry.labels
        self.manufacturer = registry.manufacturer
        self.model = registry.model
        self.modelID = registry.modelID
        self.modifiedAt = registry.modifiedAt
        self.nameByUser = registry.nameByUser
        self.name = registry.name
        self.primaryConfigEntry = registry.primaryConfigEntry
        self.serialNumber = registry.serialNumber
        self.swVersion = registry.swVersion
        self.viaDeviceID = registry.viaDeviceID
    }

    public var id: String {
        "\(serverId)-\(deviceId)"
    }

    // Computed helpers (same as DeviceRegistry)
    public var displayName: String {
        nameByUser ?? name ?? model ?? deviceId
    }

    public var isDisabled: Bool { disabledBy != nil }

    public static func config(serverId: String) throws -> [AppDeviceRegistry] {
        try Current.database().read { db in
            try AppDeviceRegistry
                .filter(
                    Column(DatabaseTables.DeviceRegistry.serverId.rawValue) == serverId
                )
                .fetchAll(db)
        }
    }
}
