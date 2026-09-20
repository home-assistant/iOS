import PromiseKit
@testable import Shared
import XCTest

#if os(iOS) && !targetEnvironment(macCatalyst)
class HingeSensorTests: XCTestCase {
    private var request: SensorProviderRequest = .init(
        reason: .trigger("unit-test"),
        dependencies: .init(),
        location: nil,
        serverVersion: Version()
    )

    override func setUp() {
        super.setUp()

        // Supported regardless of the simulator's OS, so every branch is exercised wherever the
        // suite runs rather than skipped on anything older than the API.
        Current.hinge = HingeObserver(isSupported: true)
        SensorEnablementStore.resetForTesting()
    }

    override func tearDown() {
        super.tearDown()

        Current.hinge = HingeObserver()
        SensorEnablementStore.resetForTesting()
    }

    /// A device that answered and reported no hinge cannot ever produce these sensors, so they are
    /// dropped rather than listed as permanently unavailable on every iPhone that does not fold.
    func testDeviceWithoutHingeIsUnsupported() throws {
        Current.hinge.setState(nil)

        let promise = HingeSensor(request: request).sensors()
        XCTAssertThrowsError(try hang(promise)) { error in
            XCTAssertEqual(error as? HingeSensor.HingeError, .unsupported)
        }
    }

    /// Before anything has observed the hinge the sensors stay listed, so their rows remain
    /// available to switch on.
    func testNoReadingYetReportsUnavailable() throws {
        let sensors = try hang(HingeSensor(request: request).sensors())
        XCTAssertEqual(sensors.map(\.UniqueID), ["hinge_angle", "hinge_status"])
        XCTAssertEqual(sensors.compactMap { $0.State as? String }, ["unavailable", "unavailable"])
    }

    func testReportsAngleInDegreesAndStatus() throws {
        Current.hinge.setState(HingeState(angleRadians: .pi / 2, status: .partiallyOpen))

        let sensors = try hang(HingeSensor(request: request).sensors())

        let angle = try XCTUnwrap(sensors.first { $0.UniqueID == "hinge_angle" })
        XCTAssertEqual(try XCTUnwrap(angle.State as? Double), 90, accuracy: 0.05)
        XCTAssertEqual(angle.UnitOfMeasurement, "°")
        XCTAssertEqual(angle.Attributes?["status"] as? String, "partially_open")

        let status = try XCTUnwrap(sensors.first { $0.UniqueID == "hinge_status" })
        XCTAssertEqual(status.State as? String, "partially_open")
    }

    func testFullyOpenReportsOneHundredEightyDegrees() throws {
        Current.hinge.setState(HingeState(angleRadians: .pi, status: .fullyOpen))

        let sensors = try hang(HingeSensor(request: request).sensors())
        let angle = try XCTUnwrap(sensors.first { $0.UniqueID == "hinge_angle" })
        XCTAssertEqual(try XCTUnwrap(angle.State as? Double), 180, accuracy: 0.05)
        XCTAssertEqual(sensors.first { $0.UniqueID == "hinge_status" }?.State as? String, "fully_open")
    }

    /// The angle arrives in radians and every consumer downstream expects degrees.
    func testClosedHingeReportsZeroDegrees() throws {
        Current.hinge.setState(HingeState(angleRadians: 0, status: .closed))

        let sensors = try hang(HingeSensor(request: request).sensors())
        XCTAssertEqual(sensors.first { $0.UniqueID == "hinge_angle" }?.State as? Double, 0)
        XCTAssertEqual(sensors.first { $0.UniqueID == "hinge_status" }?.State as? String, "closed")
    }

    /// Every status gets its own icon, so a dashboard can tell the states apart at a glance.
    func testEachStatusReportsItsOwnIcon() throws {
        var icons: [String] = []
        for status in HingeStatus.allCases {
            Current.hinge = HingeObserver(isSupported: true)
            Current.hinge.setState(HingeState(angleDegrees: 90, status: status))

            let sensors = try hang(HingeSensor(request: request).sensors())
            let icon = try XCTUnwrap(sensors.first { $0.UniqueID == "hinge_status" }?.Icon)
            icons.append(icon)
        }
        XCTAssertEqual(Set(icons).count, HingeStatus.allCases.count, "every status needs its own icon")
    }

    /// The angle carries the status and the status carries the angle, so one sensor is enough for
    /// an automation that needs both.
    func testEachSensorCarriesTheOtherAsAnAttribute() throws {
        Current.hinge.setState(HingeState(angleDegrees: 90, status: .partiallyOpen))

        let sensors = try hang(HingeSensor(request: request).sensors())
        XCTAssertEqual(
            sensors.first { $0.UniqueID == "hinge_angle" }?.Attributes?["status"] as? String,
            "partially_open"
        )
        XCTAssertEqual(sensors.first { $0.UniqueID == "hinge_status" }?.Attributes?["angle"] as? Double, 90)
    }

    /// Angle updates arrive at whatever rate the system chooses, so the value is rounded rather
    /// than sent at full precision.
    func testAngleIsRounded() throws {
        Current.hinge.setState(HingeState(angleDegrees: 91.26, status: .partiallyOpen))

        let sensors = try hang(HingeSensor(request: request).sensors())
        XCTAssertEqual(sensors.first { $0.UniqueID == "hinge_angle" }?.State as? Double, 91.3)
    }

    func testSignalerSignalsWhenTheHingeChanges() {
        var signalCount = 0
        let signaler = HingeSensorUpdateSignaler(signal: { signalCount += 1 })
        signaler.observe()

        Current.hinge.setState(HingeState(angleDegrees: 90, status: .partiallyOpen))

        let expectation = expectation(description: "signalled")
        DispatchQueue.main.async { expectation.fulfill() }
        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(signalCount, 1)
    }

    func testSignalerStopsSignallingOnceStopped() {
        var signalCount = 0
        let signaler = HingeSensorUpdateSignaler(signal: { signalCount += 1 })

        signaler.observe()
        // observe() is idempotent while already observing
        signaler.observe()
        signaler.stopObserving()
        // stopObserving() is idempotent too
        signaler.stopObserving()

        Current.hinge.setState(HingeState(angleDegrees: 90, status: .partiallyOpen))

        let expectation = expectation(description: "settled")
        DispatchQueue.main.async { expectation.fulfill() }
        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(signalCount, 0)
    }

    /// An OS without the API can never report a hinge, so the sensors are dropped outright.
    func testUnsupportedSystemIsUnsupported() {
        Current.hinge = HingeObserver(isSupported: false)

        let promise = HingeSensor(request: request).sensors()
        XCTAssertThrowsError(try hang(promise)) { error in
            XCTAssertEqual(error as? HingeSensor.HingeError, .unsupported)
        }
    }
}

class HingeObserverTests: XCTestCase {
    /// Until something reports, a hinge-less device and an unobserved one look the same, which is
    /// what `hasReceivedUpdate` exists to tell apart.
    func testHasReceivedUpdateOnlyAfterSomethingReports() {
        let observer = HingeObserver()
        XCTAssertFalse(observer.hasReceivedUpdate)
        XCTAssertNil(observer.state)

        observer.setState(nil)
        XCTAssertTrue(observer.hasReceivedUpdate)
        XCTAssertNil(observer.state)
    }

    func testStateIsKept() {
        let observer = HingeObserver()
        observer.setState(HingeState(angleDegrees: 45, status: .partiallyOpen))
        XCTAssertEqual(observer.state, HingeState(angleDegrees: 45, status: .partiallyOpen))
    }

    func testStatePublisherEmitsEveryChange() {
        let observer = HingeObserver()
        var received: [HingeState?] = []
        let cancellable = observer.statePublisher.sink { received.append($0) }

        observer.setState(HingeState(angleDegrees: 45, status: .partiallyOpen))
        // The same reading again is not a change, so it is not republished.
        observer.setState(HingeState(angleDegrees: 45, status: .partiallyOpen))
        observer.setState(nil)

        cancellable.cancel()
        XCTAssertEqual(received, [nil, HingeState(angleDegrees: 45, status: .partiallyOpen), nil])
    }

    /// Whatever this machine answers, it has to answer without crashing — and on anything older
    /// than the API it has to answer no.
    func testSystemSupportIsFalseBelowTheAPI() {
        if #available(iOS 27.1, *) {
            XCTAssertTrue(HingeObserver.systemSupportsHinge)
        } else {
            XCTAssertFalse(HingeObserver.systemSupportsHinge)
        }
    }
}

class HingeStateTests: XCTestCase {
    func testRadiansConvertToDegrees() {
        XCTAssertEqual(HingeState(angleRadians: .pi, status: .fullyOpen).angleDegrees, 180, accuracy: 0.0001)
        XCTAssertEqual(HingeState(angleRadians: .pi / 4, status: .partiallyOpen).angleDegrees, 45, accuracy: 0.0001)
    }

    /// UIKit's `UIHinge.Status` is `unknown` 0, `closed` 1, `partiallyOpen` 2, `fullyOpen` 3.
    func testUIKitStatusRawValuesMapAcross() {
        XCTAssertEqual(HingeStatus(uiKitStatusRawValue: 0), .unknown)
        XCTAssertEqual(HingeStatus(uiKitStatusRawValue: 1), .closed)
        XCTAssertEqual(HingeStatus(uiKitStatusRawValue: 2), .partiallyOpen)
        XCTAssertEqual(HingeStatus(uiKitStatusRawValue: 3), .fullyOpen)
    }

    /// A case UIKit adds later reads as unknown rather than as whichever case happens to be first.
    func testUnrecognisedUIKitStatusIsUnknown() {
        XCTAssertEqual(HingeStatus(uiKitStatusRawValue: 4), .unknown)
        XCTAssertEqual(HingeStatus(uiKitStatusRawValue: -1), .unknown)
    }

    func testBuildsFromUIKitValuesDirectly() {
        let state = HingeState(angleRadians: .pi, uiKitStatusRawValue: 3)
        XCTAssertEqual(state.angleDegrees, 180, accuracy: 0.0001)
        XCTAssertEqual(state.status, .fullyOpen)
    }

    /// The raw values are the sensor's state, so Home Assistant keeps storing them: changing one
    /// changes what every existing automation compares against.
    func testRawValuesAreStable() {
        XCTAssertEqual(HingeStatus.unknown.rawValue, "unknown")
        XCTAssertEqual(HingeStatus.closed.rawValue, "closed")
        XCTAssertEqual(HingeStatus.partiallyOpen.rawValue, "partially_open")
        XCTAssertEqual(HingeStatus.fullyOpen.rawValue, "fully_open")
    }
}
#endif
