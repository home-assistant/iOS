import Foundation
import GRDB
@testable import Shared

extension DatabaseQueue {
    /// Creates every table of the app's schema on this database, the way the app does at launch, without
    /// touching the app group defaults.
    ///
    /// Creating `AllowedTagTable` migrates the legacy `allowedTags` preference: it reads the key from
    /// `Current.settingsStore.prefs` and deletes it. Even under `.isolatedEnvironment` that store is the
    /// app group defaults every test in the process shares, so a test creating the schema in parallel
    /// could consume tags another test seeded there. This points `Current.settingsStore` at an empty
    /// defaults suite of this call's own while the tables are created, then puts the previous store back
    /// and deletes the suite.
    ///
    /// It assigns `Current.settingsStore`, so call it only from a test that owns its environment
    /// (`.isolatedEnvironment`) or holds the shared-state lock (`.sharedState`).
    func createSchemaWithPrivateDefaults() throws {
        let suiteName = "io.home-assistant.tests.\(UUID().uuidString)"
        guard let prefs = UserDefaults(suiteName: suiteName) else {
            fatalError("Could not create the defaults suite \(suiteName)")
        }
        let previous = Current.settingsStore
        Current.settingsStore = SettingsStore(prefs: prefs)
        defer {
            Current.settingsStore = previous
            prefs.removePersistentDomain(forName: suiteName)
        }
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: self)
        }
    }
}
