import Foundation
import GRDB
import Shared

/// Configuration for the Assist feature, persisted in the database
struct AssistConfiguration: Codable, Identifiable, Equatable, PersistableRecord, FetchableRecord {
    /// Singleton ID for the configuration (only one row in the database)
    static let singletonID = "assist_config"

    static let defaultVadSilenceSeconds = 0.7
    static let defaultVadTimeoutSeconds = 15.0
    static let vadSilenceSecondsRange = 0.1...5.0
    static let vadTimeoutSecondsRange = 1.0...120.0

    var id: String = AssistConfiguration.singletonID
    var enableOnDeviceSTT: Bool = false
    var onDeviceSTTLocaleIdentifier: String? = nil
    var muteTTS: Bool = false
    var enableOnDeviceTTS: Bool = false
    var onDeviceTTSVoiceIdentifier: String? = nil
    var vadSilenceSeconds: Double? = nil
    var vadTimeoutSeconds: Double? = nil

    var isCustomVadSettingsEnabled: Bool {
        vadSilenceSeconds != nil || vadTimeoutSeconds != nil
    }

    /// Custom row initializer to handle NULL values from migrated columns.
    init(row: Row) throws {
        self.id = row[DatabaseTables.AssistConfiguration.id.rawValue]
        self.enableOnDeviceSTT = row[DatabaseTables.AssistConfiguration.enableOnDeviceSTT.rawValue] ?? false
        self.onDeviceSTTLocaleIdentifier = row[DatabaseTables.AssistConfiguration.onDeviceSTTLocaleIdentifier.rawValue]
        self.muteTTS = row[DatabaseTables.AssistConfiguration.muteTTS.rawValue] ?? false
        self.enableOnDeviceTTS = row[DatabaseTables.AssistConfiguration.enableOnDeviceTTS.rawValue] ?? false
        self.onDeviceTTSVoiceIdentifier = row[DatabaseTables.AssistConfiguration.onDeviceTTSVoiceIdentifier.rawValue]
        self.vadSilenceSeconds = row[DatabaseTables.AssistConfiguration.vadSilenceSeconds.rawValue]
        self.vadTimeoutSeconds = row[DatabaseTables.AssistConfiguration.vadTimeoutSeconds.rawValue]
    }

    init(
        id: String = AssistConfiguration.singletonID,
        enableOnDeviceSTT: Bool = false,
        onDeviceSTTLocaleIdentifier: String? = nil,
        muteTTS: Bool = false,
        enableOnDeviceTTS: Bool = false,
        onDeviceTTSVoiceIdentifier: String? = nil,
        vadSilenceSeconds: Double? = nil,
        vadTimeoutSeconds: Double? = nil
    ) {
        self.id = id
        self.enableOnDeviceSTT = enableOnDeviceSTT
        self.onDeviceSTTLocaleIdentifier = onDeviceSTTLocaleIdentifier
        self.muteTTS = muteTTS
        self.enableOnDeviceTTS = enableOnDeviceTTS
        self.onDeviceTTSVoiceIdentifier = onDeviceTTSVoiceIdentifier
        self.vadSilenceSeconds = vadSilenceSeconds
        self.vadTimeoutSeconds = vadTimeoutSeconds
    }

    static var config: AssistConfiguration {
        do {
            return try Current.database().read { db in
                if let config = try AssistConfiguration.fetchOne(db, key: AssistConfiguration.singletonID) {
                    return config
                } else {
                    Current.Log.info("No AssistConfiguration found in database, returning default")
                    return AssistConfiguration()
                }
            }
        } catch {
            Current.Log.error("Failed to fetch AssistConfiguration: \(error)")
            assertionFailure("Failed to fetch AssistConfiguration: \(error)")
            return AssistConfiguration()
        }
    }

    mutating func setCustomVadSettingsEnabled(_ enabled: Bool) {
        if enabled {
            vadSilenceSeconds = vadSilenceSeconds ?? Self.defaultVadSilenceSeconds
            vadTimeoutSeconds = vadTimeoutSeconds ?? Self.defaultVadTimeoutSeconds
        } else {
            vadSilenceSeconds = nil
            vadTimeoutSeconds = nil
        }
    }

    func save() {
        do {
            try Current.database().write { db in
                try save(db, onConflict: .replace)
            }
        } catch {
            Current.Log.error("Failed to save AssistConfiguration: \(error)")
            assertionFailure("Failed to save AssistConfiguration: \(error)")
        }
    }
}
