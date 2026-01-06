import Foundation
import GRDB
import HAKit

public struct EntityRegistryEntry: Codable, HADataDecodable {
    public let uniqueId: String
    public let entityId: String?
    public let platform: String?
    public let configEntryId: String?
    public let deviceId: String?
    public let areaId: String?

    public let disabledBy: String?
    public let hiddenBy: String?
    public let entityCategory: String?

    public let name: String?
    public let originalName: String?
    public let icon: String?
    public let originalIcon: String?
    public let aliases: [String]?
    public let labels: [String]?

    public let deviceClass: String?
    public let originalDeviceClass: String?
    public let capabilities: [String: AnyCodable?]?
    public let supportedFeatures: Int?
    public let unitOfMeasurement: String?

    public let options: [String: [String: AnyCodable?]]?
    public let translationKey: String?
    public let hasEntityName: Bool?

    public init(data: HAData) throws {
        self.uniqueId = try data.decode("id")
        self.entityId = try? data.decode("entity_id")
        self.platform = try? data.decode("platform")
        self.configEntryId = try? data.decode("config_entry_id")
        self.deviceId = try? data.decode("device_id")
        self.areaId = try? data.decode("area_id")

        self.disabledBy = try? data.decode("disabled_by")
        self.hiddenBy = try? data.decode("hidden_by")
        self.entityCategory = try? data.decode("entity_category")

        self.name = try? data.decode("name")
        self.originalName = try? data.decode("original_name")
        self.icon = try? data.decode("icon")
        self.originalIcon = try? data.decode("original_icon")
        self.aliases = try? data.decode("aliases")
        self.labels = try? data.decode("labels")

        self.deviceClass = try? data.decode("device_class")
        self.originalDeviceClass = try? data.decode("original_device_class")
        self.capabilities = try? data.decode("capabilities")
        self.supportedFeatures = try? data.decode("supported_features")
        self.unitOfMeasurement = try? data.decode("unit_of_measurement")

        self.options = try? data.decode("options")
        self.translationKey = try? data.decode("translation_key")
        self.hasEntityName = try? data.decode("has_entity_name")
    }

    // Computed helpers
    public var displayName: String {
        name ?? originalName ?? entityId ?? "-"
    }

    public var displayIcon: String? {
        icon ?? originalIcon
    }

    public var isDisabled: Bool { disabledBy != nil }
    public var isHidden: Bool { hiddenBy != nil }
    public var isConfiguration: Bool { entityCategory == "config" }
    public var isDiagnostic: Bool { entityCategory == "diagnostic" }
}

// MARK: - Database Model

public struct AppEntityRegistry: Codable, FetchableRecord, PersistableRecord {
    public let serverId: String

    // All EntityRegistryEntry fields
    public let uniqueId: String
    public let entityId: String?
    public let platform: String?
    public let configEntryId: String?
    public let deviceId: String?
    public let areaId: String?

    public let disabledBy: String?
    public let hiddenBy: String?
    public let entityCategory: String?

    public let name: String?
    public let originalName: String?
    public let icon: String?
    public let originalIcon: String?
    public let aliases: [String]?
    public let labels: [String]?

    public let deviceClass: String?
    public let originalDeviceClass: String?
    public let capabilities: [String: AnyCodable?]?
    public let supportedFeatures: Int?
    public let unitOfMeasurement: String?

    public let options: [String: [String: AnyCodable?]]?
    public let translationKey: String?
    public let hasEntityName: Bool?

    public init(serverId: String, registry: EntityRegistryEntry) {
        self.serverId = serverId

        // Copy all fields from EntityRegistryEntry
        self.uniqueId = registry.uniqueId
        self.entityId = registry.entityId
        self.platform = registry.platform
        self.configEntryId = registry.configEntryId
        self.deviceId = registry.deviceId
        self.areaId = registry.areaId

        self.disabledBy = registry.disabledBy
        self.hiddenBy = registry.hiddenBy
        self.entityCategory = registry.entityCategory

        self.name = registry.name
        self.originalName = registry.originalName
        self.icon = registry.icon
        self.originalIcon = registry.originalIcon
        self.aliases = registry.aliases
        self.labels = registry.labels

        self.deviceClass = registry.deviceClass
        self.originalDeviceClass = registry.originalDeviceClass
        self.capabilities = registry.capabilities
        self.supportedFeatures = registry.supportedFeatures
        self.unitOfMeasurement = registry.unitOfMeasurement

        self.options = registry.options
        self.translationKey = registry.translationKey
        self.hasEntityName = registry.hasEntityName
    }

    public var id: String {
        "\(serverId)-\(uniqueId)"
    }

    // Computed helpers (same as EntityRegistryEntry)
    public var displayName: String {
        name ?? originalName ?? entityId ?? "-"
    }

    public var displayIcon: String? {
        icon ?? originalIcon
    }

    public var isDisabled: Bool { disabledBy != nil }
    public var isHidden: Bool { hiddenBy != nil }
    public var isConfiguration: Bool { entityCategory == "config" }
    public var isDiagnostic: Bool { entityCategory == "diagnostic" }

    public static func config(serverId: String) throws -> [AppEntityRegistry] {
        try Current.database().read { db in
            try AppEntityRegistry
                .filter(
                    Column(DatabaseTables.EntityRegistry.serverId.rawValue) == serverId
                )
                .fetchAll(db)
        }
    }
}
