import PromiseKit
@testable import Shared
import Version
import XCTest

class ActiveSensorTests: XCTestCase {
    private var request: SensorProviderRequest = .init(
        reason: .trigger("unit-test"),
        dependencies: .init(),
        location: nil,
        serverVersion: Version()
    )

    private var activeState: FakeActiveStateManager!

    override func setUp() {
        super.setUp()

        activeState = FakeActiveStateManager()
        Current.activeState = activeState
    }

    override func tearDown() {
        super.tearDown()

        Current.activeState = ActiveStateManager()
    }

    func testNotAvailable() {
        activeState.overrideCanTrackActiveStatus = false

        let promise = ActiveSensor(request: request).sensors()
        XCTAssertThrowsError(try hang(promise)) { error in
            XCTAssertEqual(error as? ActiveSensor.ActiveError, .noActiveState)
        }
    }

    func testIsActive() throws {
        activeState.overrideCanTrackActiveStatus = true
        activeState.overrideIsActive = true

        let promise = ActiveSensor(request: request).sensors()
        let sensors = try hang(promise)
        XCTAssertEqual(sensors.count, 1)

        XCTAssertEqual(sensors[0].Name, "Active")
        XCTAssertEqual(sensors[0].UniqueID, "active")
        XCTAssertEqual(sensors[0].Icon, "mdi:monitor")
        XCTAssertEqual(sensors[0].Type, "binary_sensor")
        XCTAssertEqual(sensors[0].State as? Bool, true)
    }

    func testNotActive() throws {
        activeState.overrideCanTrackActiveStatus = true
        activeState.overrideIsActive = false

        let promise = ActiveSensor(request: request).sensors()
        let sensors = try hang(promise)
        XCTAssertEqual(sensors.count, 1)

        XCTAssertEqual(sensors[0].Name, "Active")
        XCTAssertEqual(sensors[0].UniqueID, "active")
        XCTAssertEqual(sensors[0].Icon, "mdi:monitor-off")
        XCTAssertEqual(sensors[0].Type, "binary_sensor")
        XCTAssertEqual(sensors[0].State as? Bool, false)
    }

    func testSignalerCreated() throws {
        activeState.overrideCanTrackActiveStatus = true
        activeState.overrideIsActive = false

        let dependencies = SensorProviderDependencies()
        let provider = ActiveSensor(request: .init(
            reason: .trigger("unit-test"),
            dependencies: dependencies,
            location: nil,
            serverVersion: Version()
        ))
        let promise = provider.sensors()
        _ = try hang(promise)

        let signaler: ActiveSensorUpdateSignaler? = dependencies.existingSignaler(for: provider)
        XCTAssertNotNil(signaler)
    }

    func testSignaler() {
        var didSignal = false
        let signaler = ActiveSensorUpdateSignaler(signal: {
            didSignal = true
        })

        signaler.activeStateDidChange(for: activeState)
        XCTAssertTrue(didSignal)
    }
}

private class FakeActiveStateManager: ActiveStateManager {
    var overrideCanTrackActiveStatus = false
    override var canTrackActiveStatus: Bool { overrideCanTrackActiveStatus }

    var overrideIsActive = false
    override var isActive: Bool { overrideIsActive }
}
