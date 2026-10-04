import Foundation
@testable import Shared
import XCTest

final class RealmToGRDBMigrationTests: XCTestCase {
    private var previousCompleted: Any?
    private var previousAttempts: Any?

    private var prefs: UserDefaults { Current.settingsStore.prefs }

    override func setUp() {
        super.setUp()
        previousCompleted = prefs.object(forKey: RealmToGRDBMigration.migrationCompletedKey)
        previousAttempts = prefs.object(forKey: RealmToGRDBMigration.migrationAttemptsKey)
    }

    override func tearDown() {
        restore(previousCompleted, forKey: RealmToGRDBMigration.migrationCompletedKey)
        restore(previousAttempts, forKey: RealmToGRDBMigration.migrationAttemptsKey)
        super.tearDown()
    }

    func testNotCompletedWithoutFlag() {
        prefs.removeObject(forKey: RealmToGRDBMigration.migrationCompletedKey)
        prefs.removeObject(forKey: RealmToGRDBMigration.migrationAttemptsKey)

        XCTAssertFalse(RealmToGRDBMigration.hasCompletedMigration)
    }

    func testCompletedWithFlagAndAttemptsWithinLimit() {
        prefs.set(true, forKey: RealmToGRDBMigration.migrationCompletedKey)
        prefs.set(RealmToGRDBMigration.maxMigrationAttempts, forKey: RealmToGRDBMigration.migrationAttemptsKey)

        XCTAssertTrue(RealmToGRDBMigration.hasCompletedMigration)
    }

    func testAbandonedMigrationIsNotConsideredComplete() {
        // giving up after too many attempts sets the flag but leaves the legacy store as the only copy
        prefs.set(true, forKey: RealmToGRDBMigration.migrationCompletedKey)
        prefs.set(RealmToGRDBMigration.maxMigrationAttempts + 1, forKey: RealmToGRDBMigration.migrationAttemptsKey)

        XCTAssertFalse(RealmToGRDBMigration.hasCompletedMigration)
    }

    func testMigrateIfNeededIsSkippedUnderTests() {
        prefs.removeObject(forKey: RealmToGRDBMigration.migrationCompletedKey)
        prefs.removeObject(forKey: RealmToGRDBMigration.migrationAttemptsKey)

        RealmToGRDBMigration.migrateIfNeeded()

        XCTAssertFalse(prefs.bool(forKey: RealmToGRDBMigration.migrationCompletedKey))
        XCTAssertEqual(prefs.integer(forKey: RealmToGRDBMigration.migrationAttemptsKey), 0)
    }

    private func restore(_ value: Any?, forKey key: String) {
        if let value {
            prefs.set(value, forKey: key)
        } else {
            prefs.removeObject(forKey: key)
        }
    }
}
