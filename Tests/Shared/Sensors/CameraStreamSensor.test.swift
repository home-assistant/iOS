import PromiseKit
@testable import Shared
import XCTest

#if os(iOS) && !targetEnvironment(macCatalyst)
class CameraStreamSensorTests: XCTestCase {
    private var request: SensorProviderRequest = .init(
        reason: .trigger("unit-test"),
        dependencies: .init(),
        location: nil,
        serverVersion: Version()
    )

    private var motionDetection: FakeMotionDetectionManager!
    private var server: FakeCameraStreamServer!

    override func setUp() {
        super.setUp()

        motionDetection = FakeMotionDetectionManager()
        Current.motionDetection = motionDetection
        server = FakeCameraStreamServer()
        Current.cameraStreamServer = server
        resetSensorEnablement()
    }

    override func tearDown() {
        super.tearDown()

        Current.motionDetection = MotionDetectionManager()
        Current.cameraStreamServer = CameraStreamServer()
        resetSensorEnablement()
    }

    private func resetSensorEnablement() {
        Current.settingsStore.prefs.removeObject(forKey: "disabledSensors")
        Current.settingsStore.prefs.removeObject(forKey: SensorContainer.initialDisableKey(for: .cameraStream))
    }

    func testNotAvailable() {
        motionDetection.overrideCanDetectMotion = false

        let promise = CameraStreamSensor(request: request).sensors()
        XCTAssertThrowsError(try hang(promise)) { error in
            XCTAssertEqual(error as? CameraStreamSensor.CameraStreamError, .unavailable)
        }
    }

    func testIdle() throws {
        motionDetection.overrideCanDetectMotion = true
        server.overrideIsStreaming = false

        let promise = CameraStreamSensor(request: request).sensors()
        let sensors = try hang(promise)
        XCTAssertEqual(sensors.count, 1)

        XCTAssertEqual(sensors[0].Name, "Camera Stream")
        XCTAssertEqual(sensors[0].UniqueID, "camera_stream")
        XCTAssertEqual(sensors[0].Icon, "mdi:cctv-off")
        XCTAssertEqual(sensors[0].State as? String, "idle")
        XCTAssertEqual(sensors[0].Settings.count, 1)
    }

    func testStreaming() throws {
        motionDetection.overrideCanDetectMotion = true
        server.overrideIsStreaming = true
        server.overrideClientCount = 2
        server.overrideStreamURL = "http://192.168.1.2:8090/"

        let promise = CameraStreamSensor(request: request).sensors()
        let sensors = try hang(promise)
        XCTAssertEqual(sensors.count, 1)

        XCTAssertEqual(sensors[0].Icon, "mdi:cctv")
        XCTAssertEqual(sensors[0].State as? String, "streaming")
        XCTAssertEqual(sensors[0].Attributes?["Port"] as? Int, 8090)
        XCTAssertEqual(sensors[0].Attributes?["Clients"] as? Int, 2)
        XCTAssertEqual(sensors[0].Attributes?["Stream URL"] as? String, "http://192.168.1.2:8090/")
    }

    func testDisabledInitiallyButUserChoiceSticks() throws {
        motionDetection.overrideCanDetectMotion = true

        _ = try hang(CameraStreamSensor(request: request).sensors())
        XCTAssertFalse(Current.sensors.isEnabled(uniqueID: WebhookSensorId.cameraStream.rawValue))

        Current.sensors.setEnabled(true, forUniqueID: WebhookSensorId.cameraStream.rawValue)
        _ = try hang(CameraStreamSensor(request: request).sensors())
        XCTAssertTrue(Current.sensors.isEnabled(uniqueID: WebhookSensorId.cameraStream.rawValue))
    }

    func testSignalerCreated() throws {
        motionDetection.overrideCanDetectMotion = true

        let dependencies = SensorProviderDependencies()
        let provider = CameraStreamSensor(request: .init(
            reason: .trigger("unit-test"),
            dependencies: dependencies,
            location: nil,
            serverVersion: Version()
        ))
        _ = try hang(provider.sensors())

        let signaler: CameraStreamSensorUpdateSignaler? = dependencies.existingSignaler(for: provider)
        XCTAssertNotNil(signaler)
    }

    func testSignalerControlsServer() {
        var didSignal = false
        let signaler = CameraStreamSensorUpdateSignaler(signal: {
            didSignal = true
        })

        signaler.observe()
        XCTAssertEqual(server.setActiveCalls, [true])
        XCTAssertNotNil(server.onStateChange)

        server.onStateChange?()
        XCTAssertTrue(didSignal)

        signaler.stopObserving()
        XCTAssertEqual(server.setActiveCalls, [true, false])
        XCTAssertNil(server.onStateChange)
    }
}

private class FakeMotionDetectionManager: MotionDetectionManager {
    var overrideCanDetectMotion = false
    override var canDetectMotion: Bool { overrideCanDetectMotion }
}

private class FakeCameraStreamServer: CameraStreamServer {
    var overrideIsStreaming = false
    override var isStreaming: Bool { overrideIsStreaming }

    var overrideClientCount = 0
    override var clientCount: Int { overrideClientCount }

    var overrideStreamURL: String?
    override var streamURL: String? { overrideStreamURL }

    var overridePort = 8090
    override var port: Int {
        get { overridePort }
        set { overridePort = newValue }
    }

    var setActiveCalls = [Bool]()
    override func setActive(_ newValue: Bool) {
        setActiveCalls.append(newValue)
    }
}
#endif
