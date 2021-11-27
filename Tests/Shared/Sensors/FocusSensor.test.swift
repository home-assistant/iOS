import PromiseKit
@testable import Shared
import SwiftUI
import Version
import XCTest

class FocusSensorTests: XCTestCase {
    private var request: SensorProviderRequest = .init(
        reason: .trigger("unit-test"),
        dependencies: .init(),
        location: nil,
        serverVersion: Version()
    )

    override func setUp() {
        super.setUp()
    }

    private func setUp(
        authorization: FocusStatusWrapper.AuthorizationStatus = .authorized,
        isAvailable: Bool = true,
        status: FocusStatusWrapper.Status = .init(isFocused: nil)
    ) {
        Current.focusStatus.authorizationStatus = { authorization }
        Current.focusStatus.isAvailable = { isAvailable }
        Current.focusStatus.status = { status }
    }

    func testNotAvailable() throws {
        setUp(isAvailable: false)

        let promise = FocusSensor(request: request).sensors()
        XCTAssertThrowsError(try hang(promise)) { error in
            XCTAssertEqual(error as? FocusSensor.FocusError, .unavailable)
        }
    }

    func testNotAuthorized() throws {
        for state: FocusStatusWrapper.AuthorizationStatus in [
            .restricted, .denied, .notDetermined,
        ] {
            setUp(authorization: state)

            let promise = FocusSensor(request: request).sensors()
            XCTAssertThrowsError(try hang(promise)) { error in
                XCTAssertEqual(error as? FocusSensor.FocusError, .unauthorized)
            }
        }
    }

    func testIsFocusedNil() throws {
        setUp(status: .init(isFocused: nil))

        let promise = FocusSensor(request: request).sensors()
        XCTAssertTrue(try hang(promise).isEmpty)
    }

    func testIsFocusedYes() throws {
        setUp(status: .init(isFocused: true))

        let promise = FocusSensor(request: request).sensors()
        let sensors = try hang(promise)
        let focusSensor = try XCTUnwrap(sensors.first(where: { $0.UniqueID == "focus" }))

        XCTAssertEqual(focusSensor.Name, "Focus")
        XCTAssertEqual(focusSensor.Icon, "mdi:moon-waning-crescent")
        XCTAssertEqual(focusSensor.Type, "binary_sensor")
        XCTAssertEqual(focusSensor.State as? Bool, true)
    }

    func testIsFocusedNo() throws {
        setUp(status: .init(isFocused: false))

        let promise = FocusSensor(request: request).sensors()
        let sensors = try hang(promise)
        let focusSensor = try XCTUnwrap(sensors.first(where: { $0.UniqueID == "focus" }))

        XCTAssertEqual(focusSensor.Name, "Focus")
        XCTAssertEqual(focusSensor.Icon, "mdi:moon-waning-crescent")
        XCTAssertEqual(focusSensor.Type, "binary_sensor")
        XCTAssertEqual(focusSensor.State as? Bool, false)
    }

    func testUpdateSignalerCreated() throws {
        setUp(status: .init(isFocused: false))

        let dependencies = SensorProviderDependencies()
        let provider = FocusSensor(request: .init(
            reason: .trigger("unit-test"),
            dependencies: dependencies,
            location: nil,
            serverVersion: Version()
        ))
        let promise = provider.sensors()
        _ = try hang(promise)

        let signaler: FocusSensorUpdateSignaler? = dependencies.existingSignaler(for: provider)
        XCTAssertNotNil(signaler)
    }

    func testSignaler() {
        let expectation = expectation(description: "signal")
        var signaler: FocusSensorUpdateSignaler? = FocusSensorUpdateSignaler(signal: {
            expectation.fulfill()
        })

        // to mute the written-but-never-read warning
        _ = signaler

        let date = Date()
        Current.isForegroundApp = { false }
        Current.focusStatus.trigger.value = date

        Current.isForegroundApp = { true }
        Current.focusStatus.trigger.value = date.addingTimeInterval(1.0)

        // so it sticks around, but we don't need to access it directly
        wait(for: [expectation], timeout: 10.0)
        signaler = nil

        Current.focusStatus.trigger.value = date.addingTimeInterval(2.0)
        // we expect this to not fire an expectation over-fulfill
    }
}
