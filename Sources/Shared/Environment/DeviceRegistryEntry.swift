import Foundation
import GRDB
import HAKit

public struct DeviceRegistryEntry: Codable, HADataDecodable {
    public let id: String
    public let areaId: String?
    public let configurationURL: String?
    public let configEntries: [String]?
    public let configEntriesSubentries: [String: [String?]]?
    /// Only sent for child devices, which carry a single config entry instead of the full lists.
    public let configEntryId: String?
    public let configSubentryId: String?
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
    /// Identifier of the device this one is a logical part of, `nil` for regular top-level devices.
    public let parentDeviceId: String?
    public let primaryConfigEntry: String?
    public let serialNumber: String?
    public let swVersion: String?
    public let viaDeviceID: String?

    public init(data: HAData) throws {
        self.areaId = try? data.decode("area_id")
        self.configurationURL = try? data.decode("configuration_url")
        self.configEntries = try? data.decode("config_entries")
        self.configEntriesSubentries = try? data.decode("config_entries_subentries")
        self.configEntryId = try? data.decode("config_entry_id")
        self.configSubentryId = try? data.decode("config_subentry_id")
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
        self.parentDeviceId = try? data.decode("parent_device_id")
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

    /// Whether this entry is a logical part of another device, sent over the wire stripped of the
    /// fields it inherits from its parent.
    var isChildDevice: Bool { parentDeviceId != nil }

    #if DEBUG
    // Test-only initializer
    public init(
        areaId: String?,
        configurationURL: String?,
        configEntries: [String]?,
        configEntriesSubentries: [String: [String?]]?,
        configEntryId: String? = nil,
        configSubentryId: String? = nil,
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
        parentDeviceId: String? = nil,
        primaryConfigEntry: String?,
        serialNumber: String?,
        swVersion: String?,
        viaDeviceID: String?
    ) {
        self.areaId = areaId
        self.configurationURL = configurationURL
        self.configEntries = configEntries
        self.configEntriesSubentries = configEntriesSubentries
        self.configEntryId = configEntryId
        self.configSubentryId = configSubentryId
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
        self.parentDeviceId = parentDeviceId
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
    /// Resolve the mixed list returned by `config/device_registry/list` into complete devices: a
    /// child device inherits the hardware and display fields it was sent stripped of, keeps its own
    /// config entry, and inherits no identity field. Nesting is single-level.
    static func resolvingChildDevices(
        _ entries: [DeviceRegistryEntry],
        serverId: String
    ) -> [AppDeviceRegistry] {
        let parents = Dictionary(
            entries.lazy.filter { !$0.isChildDevice }.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return entries.map { entry in
            AppDeviceRegistry(
                serverId: serverId,
                registry: entry,
                parent: entry.parentDeviceId.flatMap { parents[$0] }
            )
        }
    }

    init(serverId: String, registry: DeviceRegistryEntry, parent: DeviceRegistryEntry? = nil) {
        self.init(
            serverId: serverId,
            deviceId: registry.id,
            areaId: registry.areaId,
            configurationURL: registry.configurationURL ?? parent?.configurationURL,
            configEntries: registry.configEntries ?? registry.configEntryId.map { [$0] },
            configEntriesSubentries: registry.configEntriesSubentries ?? registry.configEntryId
                .map { [$0: [registry.configSubentryId]] },
            connections: registry.connections,
            createdAt: registry.createdAt,
            disabledBy: registry.disabledBy,
            entryType: registry.entryType ?? parent?.entryType,
            hwVersion: registry.hwVersion ?? parent?.hwVersion,
            identifiers: registry.identifiers,
            labels: registry.labels,
            manufacturer: registry.manufacturer ?? parent?.manufacturer,
            model: registry.model ?? parent?.model,
            modelID: registry.modelID ?? parent?.modelID,
            modifiedAt: registry.modifiedAt,
            nameByUser: registry.nameByUser,
            name: registry.name,
            parentDeviceId: registry.parentDeviceId,
            primaryConfigEntry: registry.primaryConfigEntry ?? registry.configEntryId,
            serialNumber: registry.serialNumber ?? parent?.serialNumber,
            swVersion: registry.swVersion ?? parent?.swVersion,
            viaDeviceID: registry.viaDeviceID
        )
    }

    /// `device_id → display name` for a server's devices.
    static func displayNamesById(serverId: String) -> [String: String] {
        do {
            return try config(serverId: serverId).reduce(into: [String: String]()) { result, device in
                result[device.deviceId] = device.displayName
            }
        } catch {
            Current.Log.error("Failed to fetch device names for server \(serverId): \(error)")
            return [:]
        }
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
