import Foundation
import GRDB

/// Persisted copy of a Home Assistant device registry entry, scoped to a server. The initializer
/// that maps the `DeviceRegistryEntry` websocket payload and the `Current.database()`-backed
/// queries live in extensions in the `Shared` module.
public struct AppDeviceRegistry: Codable, FetchableRecord, PersistableRecord, Equatable {
    public static var databaseTableName: String = GRDBDatabaseTable.deviceRegistry.rawValue

    public let serverId: String
    public let deviceId: String
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

    public init(
        serverId: String,
        deviceId: String,
        areaId: String?,
        configurationURL: String?,
        configEntries: [String]?,
        configEntriesSubentries: [String: [String?]]?,
        connections: [[String]]?,
        createdAt: Double?,
        disabledBy: String?,
        entryType: String?,
        hwVersion: String?,
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
        self.serverId = serverId
        self.deviceId = deviceId
        self.areaId = areaId
        self.configurationURL = configurationURL
        self.configEntries = configEntries
        self.configEntriesSubentries = configEntriesSubentries
        self.connections = connections
        self.createdAt = createdAt
        self.disabledBy = disabledBy
        self.entryType = entryType
        self.hwVersion = hwVersion
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

    public var id: String {
        "\(serverId)-\(deviceId)"
    }

    // Computed helpers (same as DeviceRegistryEntry)
    public var displayName: String {
        nameByUser ?? name ?? model ?? deviceId
    }

    public var isDisabled: Bool { disabledBy != nil }
}
