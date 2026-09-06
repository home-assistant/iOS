@testable import Shared
import Testing

/// Lives with the Manage Storage tests because that screen is what the flag gates: the inventory
/// protects the legacy Realm store until the importer has finished with it.
struct RealmToGRDBMigrationCompletionTests {
    @Test func completionReflectsTheStoredFlag() {
        let prefs = Current.settingsStore.prefs
        let key = RealmToGRDBMigration.migrationCompletedKey
        let original = prefs.object(forKey: key)
        defer {
            if let original {
                prefs.set(original, forKey: key)
            } else {
                prefs.removeObject(forKey: key)
            }
        }

        prefs.set(true, forKey: key)
        #expect(RealmToGRDBMigration.hasCompletedMigration)

        prefs.set(false, forKey: key)
        #expect(!RealmToGRDBMigration.hasCompletedMigration)
    }
}
