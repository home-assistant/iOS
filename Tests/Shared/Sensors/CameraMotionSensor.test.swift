import PromiseKit
@testable import Shared
import XCTest

#if os(iOS) && !targetEnvironment(macCatalyst)
class CameraMotionSensorTests: XCTestCase {
    private var request: SensorProviderRequest = .init(
        reason: .trigger("unit-test"),
        dependencies: .init(),
        location: nil,
        serverVersion: Version()
    )

    private var motionDetection: FakeMotionDetectionManager!

    override func setUp() {
        super.setUp()

        motionDetection = FakeMotionDetectionManager()
        Current.motionDetection = motionDetection
        resetSensorEnablement()
    }

    override func tearDown() {
        super.tearDown()

        Current.motionDetection = MotionDetectionManager()
        resetSensorEnablement()
    }

    private func resetSensorEnablement() {
        Current.settingsStore.prefs.removeObject(forKey: "disabledSensors")
        Current.settingsStore.prefs.removeObject(forKey: SensorContainer.initialDisableKey(for: .cameraMotion))
    }

    func testNotAvailable() {
        motionDetection.overrideCanDetectMotion = false

        let promise = CameraMotionSensor(request: request).sensors()
        XCTAssertThrowsError(try hang(promise)) { error in
            XCTAssertEqual(error as? CameraMotionSensor.CameraMotionError, .unavailable)
        }
    }

    func testMotionDetected() throws {
        motionDetection.overrideCanDetectMotion = true
        motionDetection.overrideIsMotionDetected = true

        let promise = CameraMotionSensor(request: request).sensors()
        let sensors = try hang(promise)
        XCTAssertEqual(sensors.count, 1)

        XCTAssertEqual(sensors[0].Name, "Camera Motion")
        XCTAssertEqual(sensors[0].UniqueID, "camera_motion")
        XCTAssertEqual(sensors[0].Icon, "mdi:motion-sensor")
        XCTAssertEqual(sensors[0].Type, "binary_sensor")
        XCTAssertEqual(sensors[0].State as? Bool, true)
        XCTAssertEqual(sensors[0].Settings.count, 3)
    }

    func testNoMotion() throws {
        motionDetection.overrideCanDetectMotion = true
        motionDetection.overrideIsMotionDetected = false

        let promise = CameraMotionSensor(request: request).sensors()
        let sensors = try hang(promise)
        XCTAssertEqual(sensors.count, 1)

        XCTAssertEqual(sensors[0].Icon, "mdi:motion-sensor-off")
        XCTAssertEqual(sensors[0].State as? Bool, false)
    }

    func testDisabledInitiallyButUserChoiceSticks() throws {
        motionDetection.overrideCanDetectMotion = true

        _ = try hang(CameraMotionSensor(request: request).sensors())
        XCTAssertFalse(Current.sensors.isEnabled(uniqueID: WebhookSensorId.cameraMotion.rawValue))

        Current.sensors.setEnabled(true, forUniqueID: WebhookSensorId.cameraMotion.rawValue)
        _ = try hang(CameraMotionSensor(request: request).sensors())
        XCTAssertTrue(Current.sensors.isEnabled(uniqueID: WebhookSensorId.cameraMotion.rawValue))
    }

    func testSignalerCreated() throws {
        motionDetection.overrideCanDetectMotion = true

        let dependencies = SensorProviderDependencies()
        let provider = CameraMotionSensor(request: .init(
            reason: .trigger("unit-test"),
            dependencies: dependencies,
            location: nil,
            serverVersion: Version()
        ))
        _ = try hang(provider.sensors())

        let signaler: CameraMotionSensorUpdateSignaler? = dependencies.existingSignaler(for: provider)
        XCTAssertNotNil(signaler)
    }

    func testSignalerSignalsOnMotionChange() {
        var didSignal = false
        let signaler = CameraMotionSensorUpdateSignaler(signal: {
            didSignal = true
        })

        signaler.motionStateDidChange(for: motionDetection)
        XCTAssertTrue(didSignal)
    }

    func testSignalerControlsCameraObservation() {
        let signaler = CameraMotionSensorUpdateSignaler(signal: {})

        signaler.observe()
        XCTAssertEqual(motionDetection.registerCount, 1)
        XCTAssertEqual(motionDetection.unregisterCount, 0)

        // observe() is idempotent while already observing
        signaler.observe()
        XCTAssertEqual(motionDetection.registerCount, 1)

        signaler.stopObserving()
        XCTAssertEqual(motionDetection.unregisterCount, 1)
    }
}

private class FakeMotionDetectionManager: MotionDetectionManager {
    var overrideCanDetectMotion = false
    override var canDetectMotion: Bool { overrideCanDetectMotion }

    var overrideIsMotionDetected = false
    override var isMotionDetected: Bool { overrideIsMotionDetected }

    var registerCount = 0
    override func register(observer: MotionDetectionObserver) {
        registerCount += 1
    }

    var unregisterCount = 0
    override func unregister(observer: MotionDetectionObserver) {
        unregisterCount += 1
    }
}
#endif
