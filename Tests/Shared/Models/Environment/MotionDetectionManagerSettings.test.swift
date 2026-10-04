#if os(iOS) && !targetEnvironment(macCatalyst)
import AVFoundation
import Foundation
@testable import Shared
import XCTest

final class MotionDetectionManagerSettingsTests: XCTestCase {
    private static let preferenceKeys = [
        "motion_detection_frame_rate",
        "motion_detection_area_threshold",
        "motion_detection_clear_delay",
    ]

    private var savedValues: [String: Any] = [:]

    override func setUp() {
        super.setUp()
        let prefs = Current.settingsStore.prefs
        savedValues = [:]
        for key in Self.preferenceKeys {
            if let value = prefs.object(forKey: key) {
                savedValues[key] = value
            }
            prefs.removeObject(forKey: key)
        }
    }

    override func tearDown() {
        let prefs = Current.settingsStore.prefs
        for key in Self.preferenceKeys {
            if let value = savedValues[key] {
                prefs.set(value, forKey: key)
            } else {
                prefs.removeObject(forKey: key)
            }
        }
        super.tearDown()
    }

    func testSettingsDefaults() {
        let manager = MotionDetectionManager()

        XCTAssertEqual(manager.frameRate, 8)
        XCTAssertEqual(manager.areaThresholdPercent, 40)
        XCTAssertEqual(manager.clearDelay, 15)
    }

    func testSettingsArePersisted() {
        let manager = MotionDetectionManager()

        manager.frameRate = 2
        manager.areaThresholdPercent = 12.5
        manager.clearDelay = 30

        let other = MotionDetectionManager()
        XCTAssertEqual(other.frameRate, 2)
        XCTAssertEqual(other.areaThresholdPercent, 12.5)
        XCTAssertEqual(other.clearDelay, 30)
    }

    func testInitialStateAndAttributes() {
        let manager = MotionDetectionManager()
        manager.frameRate = 4
        manager.areaThresholdPercent = 25
        manager.clearDelay = 10

        XCTAssertFalse(manager.isMotionDetected)
        XCTAssertNil(manager.lastMotionDate)
        XCTAssertEqual(manager.lastChangedRatio, 0)
        XCTAssertEqual(
            manager.canDetectMotion,
            AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) != nil
        )

        let attributes = manager.attributes
        XCTAssertEqual(attributes["Frame Rate"] as? Double, 4)
        XCTAssertEqual(attributes["Area Threshold (%)"] as? Double, 25)
        XCTAssertEqual(attributes["Clear Delay (s)"] as? Double, 10)
        XCTAssertEqual(attributes["Last Changed Ratio (%)"] as? Double, 0)
        XCTAssertEqual(attributes["Last Motion"] as? String, "never")
    }

    func testRegisteringAndUnregisteringObserversLeavesMotionCleared() throws {
        let manager = MotionDetectionManager()
        try XCTSkipIf(manager.canDetectMotion, "Only runs where there is no front camera to start")
        let first = Observer()
        let second = Observer()

        manager.register(observer: first)
        manager.register(observer: second)
        manager.refreshVideoOrientation()
        manager.refreshFrameRate()
        manager.unregister(observer: first)
        manager.unregister(observer: second)

        // Stopping the session clears motion on the main queue; let it run.
        let drained = expectation(description: "main queue drained")
        DispatchQueue.main.async { drained.fulfill() }
        wait(for: [drained], timeout: 5)

        XCTAssertFalse(manager.isMotionDetected)
        // Clearing an already-clear state is not a change, so observers are not told.
        XCTAssertEqual(first.changeCount, 0)
        XCTAssertEqual(second.changeCount, 0)
    }

    private final class Observer: MotionDetectionObserver {
        var changeCount = 0

        func motionStateDidChange(for manager: MotionDetectionManager) {
            changeCount += 1
        }
    }
}
#endif
