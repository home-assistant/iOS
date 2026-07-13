import Foundation
import GRDB
import Shared

// `AssistConfiguration` itself lives in the `HAModels` package; these are its database-backed
// accessors.
extension AssistConfiguration {
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
