import GRDB
@testable import HomeAssistant
@testable import Shared
import XCTest

@MainActor
final class KioskScreensaverControllerTests: XCTestCase {
    private var database: DatabaseQueue!
    private var previousDatabase: (() -> DatabaseQueue)!
    private var previousSensors: SensorContainer!
    private var kiosk: KioskModeManager!

    override func setUpWithError() throws {
        try super.setUpWithError()

        let database = try DatabaseQueue(path: ":memory:")
        try KioskSettingsTable().createIfNeeded(database: database)
        self.database = database
        previousDatabase = Current.database
        Current.database = { database }
        previousSensors = Current.sensors
        Current.sensors = SensorContainer()
        SensorEnablementStore.resetForTesting()
    }

    override func tearDown() {
        Current.sensors = previousSensors
        Current.database = previousDatabase
        SensorEnablementStore.resetForTesting()
        super.tearDown()
    }

    func testShowCommandActivatesScreensaver() throws {
        let controller = try makeController()

        kiosk.requestScreensaver(.show)

        waitUntil("screensaver active") { controller.isActive }
        XCTAssertTrue(kiosk.isScreensaverVisible)
    }

    func testShowCommandIsIgnoredWhileCameraIsOnDisplay() throws {
        let controller = try makeController()
        kiosk.setCameraOverlayVisible(true)
        pumpMainQueue()

        kiosk.requestScreensaver(.show)
        pumpMainQueue()

        XCTAssertFalse(controller.isActive)
        XCTAssertFalse(kiosk.isScreensaverVisible)
    }

    func testCameraAppearingDismissesActiveScreensaver() throws {
        let controller = try makeController()
        kiosk.requestScreensaver(.show)
        waitUntil("screensaver active") { controller.isActive }

        kiosk.setCameraOverlayVisible(true)

        waitUntil("screensaver dismissed") { !controller.isActive }
        XCTAssertFalse(kiosk.isScreensaverVisible)
    }

    func testScreensaverCanShowAgainOnceCameraIsHidden() throws {
        let controller = try makeController()
        kiosk.setCameraOverlayVisible(true)
        pumpMainQueue()
        kiosk.requestScreensaver(.show)
        pumpMainQueue()
        XCTAssertFalse(controller.isActive)

        kiosk.setCameraOverlayVisible(false)
        pumpMainQueue()
        kiosk.requestScreensaver(.show)

        waitUntil("screensaver active") { controller.isActive }
    }

    func testIdleTimerIsHeldWhileCameraIsOnDisplay() throws {
        let controller = try makeController(timeToStart: .seconds30)
        waitUntil("idle timer armed") { controller.isIdleTimerArmed }

        kiosk.setCameraOverlayVisible(true)
        waitUntil("idle timer held") { !controller.isIdleTimerArmed }

        kiosk.setCameraOverlayVisible(false)
        waitUntil("idle timer re-armed") { controller.isIdleTimerArmed }
    }

    // MARK: - Helpers

    /// Dimming goes through the environment's brightness hooks, so it never touches the main screen
    /// directly and restores what it found once the screensaver goes away.
    func testDimmingSetsAndRestoresTheScreenBrightness() throws {
        let previousGet = Current.screenBrightness
        let previousSet = Current.setScreenBrightness
        defer {
            Current.screenBrightness = previousGet
            Current.setScreenBrightness = previousSet
        }
        var brightness: CGFloat = 0.8
        Current.screenBrightness = { brightness }
        Current.setScreenBrightness = { brightness = $0 }
        let controller = try makeController(dimLevel: 0.3)

        kiosk.requestScreensaver(.show)
        waitUntil("screensaver active") { controller.isActive }
        XCTAssertEqual(brightness, 0.3, accuracy: 0.001)

        kiosk.requestScreensaver(.hide)
        waitUntil("screensaver hidden") { !controller.isActive }
        XCTAssertEqual(brightness, 0.8, accuracy: 0.001)
    }

    private func makeController(
        timeToStart: KioskScreensaverTimeout = .pushNotificationControlled,
        dimLevel: Double? = nil
    ) throws -> KioskScreensaverController {
        try database.write { db in
            var settings = KioskSettings()
            settings.enabled = true
            settings.screensaver.enabled = true
            settings.screensaver.timeToStart = timeToStart
            if let dimLevel {
                settings.screensaver.dimEnabled = true
                settings.screensaver.dimLevel = dimLevel
            }
            try settings.insert(db, onConflict: .replace)
        }
        kiosk = KioskModeManager()
        let controller = KioskScreensaverController(kiosk: kiosk)
        waitUntil("screensaver settings applied") { controller.screensaver.enabled }
        return controller
    }

    private func pumpMainQueue(for interval: TimeInterval = 0.2) {
        RunLoop.current.run(until: Date().addingTimeInterval(interval))
    }

    private func waitUntil(_ what: String, timeout: TimeInterval = 5, condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        XCTAssertTrue(condition(), "timed out waiting for \(what)")
    }
}
