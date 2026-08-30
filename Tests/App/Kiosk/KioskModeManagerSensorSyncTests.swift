import GRDB
@testable import Shared
import XCTest

/// Covers the kiosk sensor enablement sync in `KioskModeManager`, in particular that it never
/// deactivates sensors without an actual kiosk mode transition (issues #5261 / #5306).
///
/// `@MainActor` because the manager delivers its GRDB observation on the main queue and the wait
/// helpers spin the main run loop.
@MainActor
final class KioskModeManagerSensorSyncTests: XCTestCase {
    private var database: DatabaseQueue!
    private var previousDatabase: (() -> DatabaseQueue)!

    private let kioskSensorIds = [WebhookSensorId.kioskBrightness, .kioskVolume, .kioskScreensaver]

    override func setUpWithError() throws {
        try super.setUpWithError()

        let database = try DatabaseQueue(path: ":memory:")
        try KioskSettingsTable().createIfNeeded(database: database)
        self.database = database
        previousDatabase = Current.database
        Current.database = { database }

        SensorEnablementStore.resetForTesting()
    }

    override func tearDown() {
        Current.database = previousDatabase
        SensorEnablementStore.resetForTesting()
        super.tearDown()
    }

    func testObservationWithoutTransitionDoesNotDisableUserEnabledSensors() throws {
        // Kiosk mode is off (no persisted settings) and the user has the kiosk sensors enabled.
        for sensorId in kioskSensorIds {
            Current.sensors.setEnabled(true, forUniqueID: sensorId.rawValue)
        }

        let manager = KioskModeManager()
        // An unrelated settings change fires the observation (after its initial delivery, which
        // GRDB orders first) while `enabled` stays false the whole time.
        try pumpObservation(of: manager)

        for sensorId in kioskSensorIds {
            XCTAssertTrue(
                Current.sensors.isEnabled(uniqueID: sensorId.rawValue),
                "\(sensorId.rawValue) must stay enabled: no kiosk mode transition happened"
            )
        }
    }

    func testEnablingKioskModeEnablesKioskSensors() throws {
        for sensorId in kioskSensorIds {
            Current.sensors.setEnabled(false, forUniqueID: sensorId.rawValue)
        }

        let manager = KioskModeManager()

        try persistKioskSettings(enabled: true)
        waitFor(manager, kioskEnabled: true)

        for sensorId in kioskSensorIds {
            XCTAssertTrue(
                Current.sensors.isEnabled(uniqueID: sensorId.rawValue),
                "\(sensorId.rawValue) must be enabled when kiosk mode turns on"
            )
        }
    }

    func testDisablingKioskModeDisablesKioskSensors() throws {
        try persistKioskSettings(enabled: true)
        for sensorId in kioskSensorIds {
            Current.sensors.setEnabled(true, forUniqueID: sensorId.rawValue)
        }

        let manager = KioskModeManager()

        try persistKioskSettings(enabled: false)
        waitFor(manager, kioskEnabled: false)

        for sensorId in kioskSensorIds {
            XCTAssertFalse(
                Current.sensors.isEnabled(uniqueID: sensorId.rawValue),
                "\(sensorId.rawValue) must be disabled when kiosk mode turns off"
            )
        }
    }

    func testRelaunchAfterEnablingAllSensorsKeepsThemEnabled() throws {
        // Regression for #5306: "Enable all sensors" followed by an app relaunch. Each launch
        // creates a fresh manager whose observation fires with its initial value; that delivery
        // must not turn the kiosk sensors back off while kiosk mode stayed off throughout.
        for sensorId in kioskSensorIds {
            Current.sensors.setEnabled(true, forUniqueID: sensorId.rawValue)
        }

        let firstLaunch = KioskModeManager()
        try pumpObservation(of: firstLaunch)
        let secondLaunch = KioskModeManager()
        try pumpObservation(of: secondLaunch)

        for sensorId in kioskSensorIds {
            XCTAssertTrue(
                Current.sensors.isEnabled(uniqueID: sensorId.rawValue),
                "\(sensorId.rawValue) must survive relaunches while kiosk mode never changed"
            )
        }
    }

    // MARK: - Helpers

    private func persistKioskSettings(enabled: Bool) throws {
        try database.write { db in
            var settings = try KioskSettings.fetchOne(db) ?? KioskSettings()
            settings.enabled = enabled
            try settings.insert(db, onConflict: .replace)
        }
    }

    /// Flips an unrelated setting (`keepScreenOn`) and waits until the manager observes it. The
    /// observation delivers values in order, so once this change arrives the initial delivery has
    /// also happened — without `enabled` ever transitioning.
    private func pumpObservation(of manager: KioskModeManager) throws {
        let marker = !manager.settings.keepScreenOn
        try database.write { db in
            var settings = try KioskSettings.fetchOne(db) ?? KioskSettings()
            settings.keepScreenOn = marker
            try settings.insert(db, onConflict: .replace)
        }
        waitUntil("keepScreenOn marker observed") { manager.settings.keepScreenOn == marker }
    }

    private func waitFor(_ manager: KioskModeManager, kioskEnabled: Bool) {
        waitUntil("kiosk enabled == \(kioskEnabled)") { manager.settings.enabled == kioskEnabled }
    }

    private func waitUntil(_ what: String, timeout: TimeInterval = 5, condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        XCTAssertTrue(condition(), "timed out waiting for \(what)")
    }
}
