import Foundation
import GRDB
import Shared

// MARK: - Modern Assist Theme

/// Theme options for the modern Assist UI
enum ModernAssistTheme: String, CaseIterable, Identifiable, Codable, DatabaseValueConvertible {
    case homeAssistant = "Home Assistant"
    case midnight = "Midnight"
    case aurora = "Aurora"
    case sunset = "Sunset"
    case ocean = "Ocean"
    case forest = "Forest"
    case galaxy = "Galaxy"
    case lavender = "Lavender"
    case ember = "Ember"

    var id: String { rawValue }
}

// MARK: - Assist Configuration

/// Configuration for the Assist feature, persisted in the database
struct AssistConfiguration: Codable, Identifiable, Equatable, FetchableRecord, PersistableRecord {
    /// Singleton ID for the configuration (only one row in the database)
    static let singletonID = "assist_config"

    var id: String = AssistConfiguration.singletonID
    var enableOnDeviceSTT: Bool = false
    var sttLanguage: String = ""
    var enableModernUI: Bool = false
    var theme: ModernAssistTheme = .homeAssistant
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
