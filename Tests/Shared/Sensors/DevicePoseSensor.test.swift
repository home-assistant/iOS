import PromiseKit
@testable import Shared
import XCTest

#if os(iOS) && !targetEnvironment(macCatalyst)
import UIKit

class DevicePoseSensorTests: XCTestCase {
    private var originalSensors: SensorContainer!
    private var request: SensorProviderRequest = .init(
        reason: .trigger("unit-test"),
        dependencies: .init(),
        location: nil,
        serverVersion: Version()
    )

    override func setUp() {
        super.setUp()

        originalSensors = Current.sensors
        Current.sensors = SensorContainer()
        Current.hinge = HingeObserver(isSupported: true)
        SensorEnablementStore.resetForTesting()
    }

    override func tearDown() {
        super.tearDown()

        Current.hinge = HingeObserver()
        Current.sensors = originalSensors
        originalSensors = nil
        SensorEnablementStore.resetForTesting()
    }

    func testUnsupportedSystemIsUnsupported() {
        Current.hinge = HingeObserver(isSupported: false)

        XCTAssertThrowsError(try hang(DevicePoseSensor(request: request).sensors())) { error in
            XCTAssertEqual(error as? HingeSensor.HingeError, .unsupported)
        }
    }

    func testDeviceWithoutHingeIsUnsupported() {
        Current.hinge.setState(nil)

        XCTAssertThrowsError(try hang(DevicePoseSensor(request: request).sensors())) { error in
            XCTAssertEqual(error as? HingeSensor.HingeError, .unsupported)
        }
    }

    /// A device that has reported a hinge still has one when the reading goes back to nothing, so
    /// the pose stays listed, unread, rather than dropping out of the list.
    func testDeviceWhoseHingeWentAwayReportsUnavailable() throws {
        Current.hinge.setState(HingeState(angleDegrees: 90, status: .partiallyOpen))
        Current.hinge.setState(nil)

        let sensors = try hang(DevicePoseSensor(request: request).sensors())

        XCTAssertEqual(sensors.map(\.UniqueID), ["device_pose"])
        XCTAssertEqual(sensors.first?.State as? String, "unavailable")
    }

    func testNoReadingYetReportsUnavailable() throws {
        let sensors = try hang(DevicePoseSensor(request: request).sensors())

        XCTAssertEqual(sensors.map(\.UniqueID), ["device_pose"])
        XCTAssertEqual(sensors.first?.Name, "Pose")
        XCTAssertEqual(sensors.first?.State as? String, "unavailable")
    }

    func testReportsPoseFromHingeAndOrientation() throws {
        Current.hinge.setState(HingeState(angleDegrees: 100, status: .partiallyOpen))
        Current.hinge.setDeviceOrientation(rawValue: UIDeviceOrientation.landscapeLeft.rawValue)

        let sensor = try XCTUnwrap(hang(DevicePoseSensor(request: request).sensors()).first)

        XCTAssertEqual(sensor.UniqueID, "device_pose")
        XCTAssertEqual(sensor.Name, "Pose")
        XCTAssertEqual(sensor.State as? String, "laptop")
        XCTAssertEqual(sensor.Icon, "mdi:laptop")
    }

    func testEachPoseReportsItsOwnIcon() {
        let icons = DevicePose.allCases.compactMap { DevicePoseSensor.sensor(for: $0).Icon }

        XCTAssertEqual(icons.count, DevicePose.allCases.count)
        XCTAssertEqual(Set(icons).count, DevicePose.allCases.count)
    }

    func testSignalerSignalsWhenThePoseChanges() {
        var signalCount = 0
        let signaler = DevicePoseSensorUpdateSignaler(signal: { signalCount += 1 })
        signaler.observe()

        Current.hinge.setState(HingeState(angleDegrees: 0, status: .closed))
        Current.hinge.setState(HingeState(angleDegrees: 2, status: .closed))

        waitForMainQueue()
        XCTAssertEqual(signalCount, 1)
        signaler.stopObserving()
    }

    func testSignalerRecordsTheDeviceOrientation() {
        let signaler = DevicePoseSensorUpdateSignaler(signal: {})
        signaler.observe()
        Current.hinge.setDeviceOrientation(rawValue: -1)

        NotificationCenter.default.post(name: UIDevice.orientationDidChangeNotification, object: UIDevice.current)

        XCTAssertEqual(Current.hinge.deviceOrientationRawValue, UIDevice.current.orientation.rawValue)
        signaler.stopObserving()
    }

    func testSignalerStopsOnceStopped() {
        var signalCount = 0
        let signaler = DevicePoseSensorUpdateSignaler(signal: { signalCount += 1 })

        signaler.observe()
        signaler.observe()
        signaler.stopObserving()
        signaler.stopObserving()

        Current.hinge.setDeviceOrientation(rawValue: -1)
        NotificationCenter.default.post(name: UIDevice.orientationDidChangeNotification, object: UIDevice.current)
        Current.hinge.setState(HingeState(angleDegrees: 0, status: .closed))

        waitForMainQueue()
        XCTAssertEqual(signalCount, 0)
        XCTAssertEqual(Current.hinge.deviceOrientationRawValue, -1)
    }

    private func waitForMainQueue() {
        let expectation = expectation(description: "main queue drained")
        DispatchQueue.main.async { expectation.fulfill() }
        wait(for: [expectation], timeout: 1)
    }
}
#endif
