import PromiseKit
@testable import Shared
import SwiftUI
import XCTest

class FocusSensorTests: XCTestCase {
    private var request: SensorProviderRequest = .init(
        reason: .trigger("unit-test"),
        dependencies: .init(),
        location: nil
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
}
