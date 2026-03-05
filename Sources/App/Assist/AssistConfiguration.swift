import Foundation
import GRDB
import Shared

/// Configuration for the Assist feature, persisted in the database
struct AssistConfiguration: Codable, Identifiable, Equatable, FetchableRecord, PersistableRecord {
    /// Singleton ID for the configuration (only one row in the database)
    static let singletonID = "assist_config"

    var id: String = AssistConfiguration.singletonID
    var enableOnDeviceSTT: Bool = false
    var muteTTS: Bool = false

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
