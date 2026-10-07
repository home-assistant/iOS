import Foundation
import GRDB
import HAKit

public struct DeviceRegistryEntry: Codable, HADataDecodable {
    public let id: String
    public let areaId: String?
    public let configurationURL: String?
    public let configEntries: [String]?
    public let configEntriesSubentries: [String: [String?]]?
    public let connections: [[String]]?
    public let createdAt: Double?
    public let disabledBy: String?
    public let entryType: String?
    public let hwVersion: String?
    public let identifiers: [[String]]?
    public let labels: [String]?
    public let manufacturer: String?
    public let model: String?
    public let modelID: String?
    public let modifiedAt: Double?
    public let nameByUser: String?
    public let name: String?
    public let primaryConfigEntry: String?
    public let serialNumber: String?
    public let swVersion: String?
    public let viaDeviceID: String?

    public init(data: HAData) throws {
        self.areaId = try? data.decode("area_id")
        self.configurationURL = try? data.decode("configuration_url")
        self.configEntries = try? data.decode("config_entries")
        self.configEntriesSubentries = try? data.decode("config_entries_subentries")
        self.connections = try? data.decode("connections")
        self.createdAt = try? data.decode("created_at")
        self.disabledBy = try? data.decode("disabled_by")
        self.entryType = try? data.decode("entry_type")
        self.hwVersion = try? data.decode("hw_version")
        self.id = try data.decode("id")
        self.identifiers = try? data.decode("identifiers")
        self.labels = try? data.decode("labels")
        self.manufacturer = try? data.decode("manufacturer")
        self.model = try? data.decode("model")
        self.modelID = try? data.decode("model_id")
        self.modifiedAt = try? data.decode("modified_at")
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

    #if DEBUG
    // Test-only initializer
    public init(
        areaId: String?,
        configurationURL: String?,
        configEntries: [String]?,
        configEntriesSubentries: [String: [String?]]?,
        connections: [[String]]?,
        createdAt: Double?,
        disabledBy: String?,
        entryType: String?,
        hwVersion: String?,
        id: String,
        identifiers: [[String]]?,
        labels: [String]?,
        manufacturer: String?,
        model: String?,
        modelID: String?,
        modifiedAt: Double?,
        nameByUser: String?,
        name: String?,
        primaryConfigEntry: String?,
        serialNumber: String?,
        swVersion: String?,
        viaDeviceID: String?
    ) {
        self.areaId = areaId
        self.configurationURL = configurationURL
        self.configEntries = configEntries
        self.configEntriesSubentries = configEntriesSubentries
        self.connections = connections
        self.createdAt = createdAt
        self.disabledBy = disabledBy
        self.entryType = entryType
        self.hwVersion = hwVersion
        self.id = id
        self.identifiers = identifiers
        self.labels = labels
        self.manufacturer = manufacturer
        self.model = model
        self.modelID = modelID
        self.modifiedAt = modifiedAt
        self.nameByUser = nameByUser
        self.name = name
        self.primaryConfigEntry = primaryConfigEntry
        self.serialNumber = serialNumber
        self.swVersion = swVersion
        self.viaDeviceID = viaDeviceID
    }
    #endif
}

// MARK: - Database Model

// `AppDeviceRegistry` itself lives in the `HAModels` package; these map the websocket registry
// payload and provide its database-backed queries.
public extension AppDeviceRegistry {
    init(serverId: String, registry: DeviceRegistryEntry) {
        self.init(
            serverId: serverId,
            deviceId: registry.id,
            areaId: registry.areaId,
            configurationURL: registry.configurationURL,
            configEntries: registry.configEntries,
            configEntriesSubentries: registry.configEntriesSubentries,
            connections: registry.connections,
            createdAt: registry.createdAt,
            disabledBy: registry.disabledBy,
            entryType: registry.entryType,
            hwVersion: registry.hwVersion,
            identifiers: registry.identifiers,
            labels: registry.labels,
            manufacturer: registry.manufacturer,
            model: registry.model,
            modelID: registry.modelID,
            modifiedAt: registry.modifiedAt,
            nameByUser: registry.nameByUser,
            name: registry.name,
            primaryConfigEntry: registry.primaryConfigEntry,
            serialNumber: registry.serialNumber,
            swVersion: registry.swVersion,
            viaDeviceID: registry.viaDeviceID
        )
    }

    static func config(serverId: String) throws -> [AppDeviceRegistry] {
        try Current.database().read { db in
            try AppDeviceRegistry
                .filter(
                    Column(DatabaseTables.DeviceRegistry.serverId.rawValue) == serverId
                )
                .fetchAll(db)
        }
    }
}
