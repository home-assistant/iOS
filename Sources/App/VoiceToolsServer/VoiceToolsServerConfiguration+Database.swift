import Foundation
import GRDB
import Shared

// `VoiceToolsServerConfiguration` itself lives in the `HAModels` package; these are its
// database-backed accessors.
extension VoiceToolsServerConfiguration {
    static var config: VoiceToolsServerConfiguration {
        do {
            return try Current.database().read { db in
                if let config = try VoiceToolsServerConfiguration.fetchOne(
                    db,
                    key: VoiceToolsServerConfiguration.singletonID
                ) {
                    return config
                } else {
                    Current.Log.info("No VoiceToolsServerConfiguration found in database, returning default")
                    return VoiceToolsServerConfiguration()
                }
            }
        } catch {
            Current.Log.error("Failed to fetch VoiceToolsServerConfiguration: \(error)")
            assertionFailure("Failed to fetch VoiceToolsServerConfiguration: \(error)")
            return VoiceToolsServerConfiguration()
        }
    }

    func save() {
        do {
            try Current.database().write { db in
                try save(db, onConflict: .replace)
            }
        } catch {
            Current.Log.error("Failed to save VoiceToolsServerConfiguration: \(error)")
            assertionFailure("Failed to save VoiceToolsServerConfiguration: \(error)")
        }
    }
}
