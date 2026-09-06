import Foundation
@testable import Shared
import Testing

/// Lives with the Manage Storage tests because that screen is what the flag gates: the inventory
/// protects the legacy Realm store until the importer has finished with it.
///
/// One test rather than three: they all move the same process-wide defaults, and the suite runs its
/// tests in parallel.
struct RealmToGRDBMigrationCompletionTests {
    @Test func completionMeansTheImportFinished() {
        let prefs = Current.settingsStore.prefs
        let completedKey = RealmToGRDBMigration.migrationCompletedKey
        let attemptsKey = RealmToGRDBMigration.migrationAttemptsKey
        let originalCompleted = prefs.object(forKey: completedKey)
        let originalAttempts = prefs.object(forKey: attemptsKey)
        defer {
            restore(originalCompleted, forKey: completedKey, in: prefs)
            restore(originalAttempts, forKey: attemptsKey, in: prefs)
        }

        prefs.set(true, forKey: completedKey)
        prefs.set(1, forKey: attemptsKey)
        #expect(RealmToGRDBMigration.hasCompletedMigration)

        prefs.set(false, forKey: completedKey)
        #expect(!RealmToGRDBMigration.hasCompletedMigration)

        // The importer sets the same flag when it gives up, and that path leaves the store on disk:
        // it can still be the only copy of what never made it across.
        prefs.set(true, forKey: completedKey)
        prefs.set(RealmToGRDBMigration.maxMigrationAttempts + 1, forKey: attemptsKey)
        #expect(!RealmToGRDBMigration.hasCompletedMigration)
    }

    private func restore(_ value: Any?, forKey key: String, in prefs: UserDefaults) {
        if let value {
            prefs.set(value, forKey: key)
        } else {
            prefs.removeObject(forKey: key)
        }
    }
}
