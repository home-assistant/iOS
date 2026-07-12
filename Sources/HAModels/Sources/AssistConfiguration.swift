import Foundation
import GRDB

/// Configuration for the Assist feature, persisted in the database. The `Current.database()`-backed
/// accessors live in an extension in the app.
public struct AssistConfiguration: Codable, Identifiable, Equatable, PersistableRecord, FetchableRecord {
    /// Singleton ID for the configuration (only one row in the database)
    public static let singletonID = "assist_config"

    public var id: String = AssistConfiguration.singletonID
    public var enableOnDeviceSTT: Bool = false
    public var onDeviceSTTLocaleIdentifier: String? = nil
    public var muteTTS: Bool = false
    public var enableOnDeviceTTS: Bool = false
    public var onDeviceTTSVoiceIdentifier: String? = nil

    /// Custom row initializer to handle NULL values from migrated columns.
    public init(row: Row) throws {
        self.id = row[DatabaseTables.AssistConfiguration.id.rawValue]
        self.enableOnDeviceSTT = row[DatabaseTables.AssistConfiguration.enableOnDeviceSTT.rawValue] ?? false
        self.onDeviceSTTLocaleIdentifier = row[DatabaseTables.AssistConfiguration.onDeviceSTTLocaleIdentifier.rawValue]
        self.muteTTS = row[DatabaseTables.AssistConfiguration.muteTTS.rawValue] ?? false
        self.enableOnDeviceTTS = row[DatabaseTables.AssistConfiguration.enableOnDeviceTTS.rawValue] ?? false
        self.onDeviceTTSVoiceIdentifier = row[DatabaseTables.AssistConfiguration.onDeviceTTSVoiceIdentifier.rawValue]
    }

    public init(
        id: String = AssistConfiguration.singletonID,
        enableOnDeviceSTT: Bool = false,
        onDeviceSTTLocaleIdentifier: String? = nil,
        muteTTS: Bool = false,
        enableOnDeviceTTS: Bool = false,
        onDeviceTTSVoiceIdentifier: String? = nil
    ) {
        self.id = id
        self.enableOnDeviceSTT = enableOnDeviceSTT
        self.onDeviceSTTLocaleIdentifier = onDeviceSTTLocaleIdentifier
        self.muteTTS = muteTTS
        self.enableOnDeviceTTS = enableOnDeviceTTS
        self.onDeviceTTSVoiceIdentifier = onDeviceTTSVoiceIdentifier
    }
}
