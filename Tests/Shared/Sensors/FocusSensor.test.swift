import PromiseKit
@testable import Shared
import SwiftUI
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
        Current.focusFilter = FocusFilterWrapper()
        Current.focusStatus = FocusStatusWrapper()
        Current.focusFilter.state.value = nil
        Current.focusStatus.receivedStatus.value = nil
    }

    override func tearDown() {
        Current.focusFilter.state.value = nil
        Current.focusStatus.receivedStatus.value = nil
        Current.focusFilter = FocusFilterWrapper()
        Current.focusStatus = FocusStatusWrapper()
        super.tearDown()
    }

    private func setUpDependencies(
        authorization: FocusStatusWrapper.AuthorizationStatus = .authorized,
        isAvailable: Bool = true,
        status: FocusStatusWrapper.Status = .init(isFocused: nil),
        filterState: FocusFilterState? = nil,
        receivedStatus: FocusStatusState? = nil
    ) {
        Current.focusStatus.authorizationStatus = { authorization }
        Current.focusStatus.isAvailable = { isAvailable }
        Current.focusStatus.status = { status }
        Current.focusStatus.lastReceived = { receivedStatus }
        Current.focusFilter.activeFocusState = { filterState }
    }

    func testNotAvailable() throws {
        setUpDependencies(isAvailable: false)

        let promise = FocusSensor(request: request).sensors()
        XCTAssertThrowsError(try hang(promise)) { error in
            XCTAssertEqual(error as? FocusSensor.FocusError, .unavailable)
        }
    }

    func testNotAuthorized() throws {
        for state: FocusStatusWrapper.AuthorizationStatus in [
            .restricted, .denied, .notDetermined,
        ] {
            setUpDependencies(authorization: state)

            let promise = FocusSensor(request: request).sensors()
            XCTAssertThrowsError(try hang(promise)) { error in
                XCTAssertEqual(error as? FocusSensor.FocusError, .unauthorized)
            }
        }
    }

    func testIsFocusedNil() throws {
        setUpDependencies(status: .init(isFocused: nil))

        let promise = FocusSensor(request: request).sensors()
        XCTAssertTrue(try hang(promise).isEmpty)
    }

    func testIsFocusedYes() throws {
        setUpDependencies(status: .init(isFocused: true))

        let promise = FocusSensor(request: request).sensors()
        let sensors = try hang(promise)
        let focusSensor = try XCTUnwrap(sensors.first(where: { $0.UniqueID == "focus" }))

        XCTAssertEqual(focusSensor.Name, "Focus")
        XCTAssertEqual(focusSensor.Icon, "mdi:moon-waning-crescent")
        XCTAssertEqual(focusSensor.Type, "binary_sensor")
        XCTAssertEqual(focusSensor.State as? Bool, true)
    }

    func testIsFocusedNo() throws {
        setUpDependencies(status: .init(isFocused: false))

        let promise = FocusSensor(request: request).sensors()
        let sensors = try hang(promise)
        let focusSensor = try XCTUnwrap(sensors.first(where: { $0.UniqueID == "focus" }))

        XCTAssertEqual(focusSensor.Name, "Focus")
        XCTAssertEqual(focusSensor.Icon, "mdi:moon-waning-crescent")
        XCTAssertEqual(focusSensor.Type, "binary_sensor")
        XCTAssertEqual(focusSensor.State as? Bool, false)
    }

    /// A named Focus Filter run is proof a Focus started, standing even while the live status
    /// still describes the Focus that just ended — this is what flips the sensor to true when iOS
    /// wakes us for a Focus change.
    func testIsFocusedYesWhileNamedFilterRunStandsDespiteLiveNo() throws {
        setUpDependencies(
            status: .init(isFocused: false),
            filterState: .init(name: "Personal", date: Date(), lastKnownName: "Personal")
        )

        let sensors = try hang(FocusSensor(request: request).sensors())
        let focusSensor = try XCTUnwrap(sensors.first(where: { $0.UniqueID == "focus" }))
        XCTAssertEqual(focusSensor.State as? Bool, true)
    }

    /// The filter path doesn't need the Focus status permission, so a named run answers even when
    /// the live status can't.
    func testIsFocusedYesFromNamedFilterRunWithoutAuthorization() throws {
        setUpDependencies(
            authorization: .denied,
            filterState: .init(name: "Personal", date: Date(), lastKnownName: "Personal")
        )

        let sensors = try hang(FocusSensor(request: request).sensors())
        let focusSensor = try XCTUnwrap(sensors.first(where: { $0.UniqueID == "focus" }))
        XCTAssertEqual(focusSensor.State as? Bool, true)
    }

    /// The nil-name run iOS makes when a Focus deactivates is not proof one is on: the pushed
    /// status decides.
    func testFilterResetRunDefersToTheReceivedStatus() throws {
        let now = Date()
        setUpDependencies(
            filterState: .init(name: nil, date: now, lastKnownName: "Personal"),
            receivedStatus: .init(isFocused: false, date: now, lastEndedDate: now)
        )

        let sensors = try hang(FocusSensor(request: request).sensors())
        let focusSensor = try XCTUnwrap(sensors.first(where: { $0.UniqueID == "focus" }))
        XCTAssertEqual(focusSensor.State as? Bool, false)
    }

    func testUpdateSignalerCreated() throws {
        setUpDependencies(status: .init(isFocused: false))

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

    @MainActor
    func testSignaler() async throws {
        setUpDependencies(
            authorization: .authorized,
            isAvailable: true,
            status: .init(focusStatus: .init(isFocused: true))
        )
        _ = Current.sensors.sensors(reason: .registration, server: ServerFixture.standard)

        let expectation1 = expectation(description: "Observation")
        let expectation2 = expectation(description: "Signal")
        let signaler = FocusSensorUpdateSignaler(signal: {
            expectation2.fulfill()
        })

        signaler.notifyObservation = {
            expectation1.fulfill()
        }

        await fulfillment(of: [expectation1], timeout: 10)

        let date = Date()
        Current.isForegroundApp = { false }
        Current.focusStatus.receivedStatus.value = .init(isFocused: true, date: date, lastEndedDate: nil)

        Current.isForegroundApp = { true }
        Current.focusStatus.receivedStatus.value = .init(
            isFocused: true,
            date: date.addingTimeInterval(1.0),
            lastEndedDate: nil
        )

        // so it sticks around, but we don't need to access it directly
        await fulfillment(of: [expectation2], timeout: 10)
    }
}
