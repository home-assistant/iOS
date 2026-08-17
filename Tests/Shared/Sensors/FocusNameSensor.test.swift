import GRDB
import PromiseKit
@testable import Shared
import XCTest

class FocusNameSensorTests: XCTestCase {
    private var request: SensorProviderRequest = .init(
        reason: .trigger("unit-test"),
        dependencies: .init(),
        location: nil,
        serverVersion: Version()
    )

    override func setUpWithError() throws {
        try super.setUpWithError()
        try clearFocusNames()
        Current.focusFilter = FocusFilterWrapper()
        Current.focusStatus = FocusStatusWrapper()
    }

    override func tearDownWithError() throws {
        try clearFocusNames()
        Current.focusFilter = FocusFilterWrapper()
        Current.focusStatus = FocusStatusWrapper()
        try super.tearDownWithError()
    }

    private func clearFocusNames() throws {
        try Current.database().write { db in
            _ = try FocusName.deleteAll(db)
        }
    }

    private func setUpDependencies(
        activeFocusName: String?,
        isFocused: Bool?,
        focusAuthorization: FocusStatusWrapper.AuthorizationStatus = .authorized,
        focusAvailable: Bool = true
    ) {
        Current.focusFilter.activeFocusName = { activeFocusName }
        Current.focusStatus.isAvailable = { focusAvailable }
        Current.focusStatus.authorizationStatus = { focusAuthorization }
        Current.focusStatus.status = { .init(isFocused: isFocused) }
    }

    func testUnconfiguredWithoutNamesOrActiveName() throws {
        setUpDependencies(activeFocusName: nil, isFocused: true)

        let promise = FocusNameSensor(request: request).sensors()
        XCTAssertThrowsError(try hang(promise)) { error in
            XCTAssertEqual(error as? FocusNameSensor.FocusNameError, .unconfigured)
        }
    }

    func testReportsActiveNameWhileFocused() throws {
        FocusName(name: "Work").save()
        setUpDependencies(activeFocusName: "Work", isFocused: true)

        let sensors = try hang(FocusNameSensor(request: request).sensors())
        XCTAssertEqual(sensors.count, 1)
        XCTAssertEqual(sensors[0].UniqueID, "focus_name")
        XCTAssertEqual(sensors[0].State as? String, "Work")
        XCTAssertEqual(sensors[0].Attributes?["Is focused"] as? Bool, true)
    }

    func testReportsNotFocusedEvenWithStaleName() throws {
        FocusName(name: "Work").save()
        setUpDependencies(activeFocusName: "Work", isFocused: false)

        let sensors = try hang(FocusNameSensor(request: request).sensors())
        XCTAssertEqual(sensors[0].State as? String, FocusNameSensor.notFocusedState)
        XCTAssertEqual(sensors[0].Attributes?["Is focused"] as? Bool, false)
    }

    /// A configured name with nothing reported yet: the user created names but hasn't paired a
    /// Focus Filter with them, so we can't tell which Focus is running.
    func testReportsUnknownWhenNoFilterReported() throws {
        FocusName(name: "Work").save()
        setUpDependencies(activeFocusName: nil, isFocused: true)

        let sensors = try hang(FocusNameSensor(request: request).sensors())
        XCTAssertEqual(sensors[0].State as? String, FocusNameSensor.unknownState)
    }

    /// Without the Focus status permission the filter's name is all we have, and the "no Focus is
    /// running" attribute has to be left off rather than guessed.
    func testReportsNameWithoutFocusAuthorization() throws {
        setUpDependencies(activeFocusName: "Sleep", isFocused: false, focusAuthorization: .denied)

        let sensors = try hang(FocusNameSensor(request: request).sensors())
        XCTAssertEqual(sensors[0].State as? String, "Sleep")
        XCTAssertNil(sensors[0].Attributes?["Is focused"])
    }

    func testReportsNameWhenFocusStatusUnavailable() throws {
        setUpDependencies(activeFocusName: "Sleep", isFocused: false, focusAvailable: false)

        let sensors = try hang(FocusNameSensor(request: request).sensors())
        XCTAssertEqual(sensors[0].State as? String, "Sleep")
        XCTAssertNil(sensors[0].Attributes?["Is focused"])
    }
}
