@testable import Shared
import XCTest

final class SettingsStoreRestoreLastURLTests: XCTestCase {
    private var originalIsCatalyst: Bool!

    override func setUp() {
        super.setUp()
        originalIsCatalyst = Current.isCatalyst
        Current.isCatalyst = false
        removePersistedKeys()
    }

    override func tearDown() {
        removePersistedKeys()
        Current.isCatalyst = originalIsCatalyst
        super.tearDown()
    }

    private func removePersistedKeys() {
        Current.settingsStore.prefs.removeObject(forKey: "restoreLastURL")
        Current.settingsStore.prefs.removeObject(forKey: "migratedRestoreLastURLOptIn")
    }

    func testDefaultsToDisabledOnFreshInstall() {
        XCTAssertFalse(Current.settingsStore.restoreLastURL)
    }

    func testDefaultsToEnabledOnCatalyst() {
        // Catalyst hides the toggle, so the enabled default is the only way restore works there
        Current.isCatalyst = true
        XCTAssertTrue(Current.settingsStore.restoreLastURL)
    }

    func testMigrationKeepsEnabledForExistingInstall() {
        Current.settingsStore.migrateRestoreLastURLToOptInIfNeeded(hasExistingServers: true)
        XCTAssertTrue(Current.settingsStore.restoreLastURL)
    }

    func testMigrationRespectsExplicitOptOut() {
        Current.settingsStore.restoreLastURL = false
        Current.settingsStore.migrateRestoreLastURLToOptInIfNeeded(hasExistingServers: true)
        XCTAssertFalse(Current.settingsStore.restoreLastURL)
    }

    func testMigrationLeavesFreshInstallDisabled() {
        Current.settingsStore.migrateRestoreLastURLToOptInIfNeeded(hasExistingServers: false)
        XCTAssertFalse(Current.settingsStore.restoreLastURL)
    }

    func testMigrationRunsOnlyOnce() {
        // A fresh install adds its first server after the initial launch already ran the
        // migration; the later launch must not flip the new opt-in default to enabled.
        Current.settingsStore.migrateRestoreLastURLToOptInIfNeeded(hasExistingServers: false)
        Current.settingsStore.migrateRestoreLastURLToOptInIfNeeded(hasExistingServers: true)
        XCTAssertFalse(Current.settingsStore.restoreLastURL)
    }
}
