import Foundation
import GRDB
import Shared

/// Configuration for the Assist feature, persisted in the database
struct AssistConfiguration: Codable, Identifiable, Equatable, PersistableRecord, FetchableRecord {
    /// Singleton ID for the configuration (only one row in the database)
    static let singletonID = "assist_config"

    var id: String = AssistConfiguration.singletonID
    var enableOnDeviceSTT: Bool = false
    var onDeviceSTTLocaleIdentifier: String? = nil
    var muteTTS: Bool = false
    var enableOnDeviceTTS: Bool = false

    /// Custom row initializer to handle NULL values from migrated columns.
    init(row: Row) throws {
        self.id = row[DatabaseTables.AssistConfiguration.id.rawValue]
        self.enableOnDeviceSTT = row[DatabaseTables.AssistConfiguration.enableOnDeviceSTT.rawValue] ?? false
        self.onDeviceSTTLocaleIdentifier = row[DatabaseTables.AssistConfiguration.onDeviceSTTLocaleIdentifier.rawValue]
        self.muteTTS = row[DatabaseTables.AssistConfiguration.muteTTS.rawValue] ?? false
        self.enableOnDeviceTTS = row[DatabaseTables.AssistConfiguration.enableOnDeviceTTS.rawValue] ?? false
    }

    init(
        id: String = AssistConfiguration.singletonID,
        enableOnDeviceSTT: Bool = false,
        onDeviceSTTLocaleIdentifier: String? = nil,
        muteTTS: Bool = false,
        enableOnDeviceTTS: Bool = false
    ) {
        self.id = id
        self.enableOnDeviceSTT = enableOnDeviceSTT
        self.onDeviceSTTLocaleIdentifier = onDeviceSTTLocaleIdentifier
        self.muteTTS = muteTTS
        self.enableOnDeviceTTS = enableOnDeviceTTS
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
