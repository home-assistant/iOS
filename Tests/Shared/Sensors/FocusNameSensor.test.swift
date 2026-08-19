import GRDB
import Intents
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

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    override func setUpWithError() throws {
        try super.setUpWithError()
        try clearFocusNames()
        Current.focusFilter = FocusFilterWrapper()
        Current.focusStatus = FocusStatusWrapper()
        Current.focusFilter.state.value = nil
        Current.focusStatus.receivedStatus.value = nil
        Current.date = { [now] in now }
    }

    override func tearDownWithError() throws {
        try clearFocusNames()
        Current.focusFilter.state.value = nil
        Current.focusStatus.receivedStatus.value = nil
        Current.focusFilter = FocusFilterWrapper()
        Current.focusStatus = FocusStatusWrapper()
        Current.isAppExtension = false
        Current.date = Date.init
        try super.tearDownWithError()
    }

    private func clearFocusNames() throws {
        try Current.database().write { db in
            _ = try FocusName.deleteAll(db)
        }
    }

    /// - Parameters:
    ///   - filterRan: how long before now the Focus Filter reported `activeFocusName`, so a test
    ///     can place it before or after what the Focus status pushed.
    ///   - receivedStatus: what iOS last pushed us, which is what tells us a Focus ended.
    private func setUpDependencies(
        activeFocusName: String?,
        filterRan: TimeInterval = -60,
        receivedStatus: FocusStatusState? = nil,
        liveIsFocused: Bool? = nil,
        focusAuthorization: FocusStatusWrapper.AuthorizationStatus = .authorized,
        focusAvailable: Bool = true
    ) {
        Current.focusFilter.activeFocusState = { [now] in
            activeFocusName.map { FocusFilterState(name: $0, date: now.addingTimeInterval(filterRan)) }
        }
        Current.focusStatus.lastReceived = { receivedStatus }
        Current.focusStatus.isAvailable = { focusAvailable }
        Current.focusStatus.authorizationStatus = { focusAuthorization }
        Current.focusStatus.status = { .init(isFocused: liveIsFocused) }
    }

    private func received(
        isFocused: Bool?,
        at offset: TimeInterval,
        lastEnded: TimeInterval? = nil
    ) -> FocusStatusState {
        let date = now.addingTimeInterval(offset)
        return FocusStatusState(
            isFocused: isFocused,
            date: date,
            lastEndedDate: lastEnded.map { now.addingTimeInterval($0) } ?? (isFocused == false ? date : nil)
        )
    }

    func testUnconfiguredWithoutNamesOrActiveName() throws {
        setUpDependencies(activeFocusName: nil, liveIsFocused: true)

        let promise = FocusNameSensor(request: request).sensors()
        XCTAssertThrowsError(try hang(promise)) { error in
            XCTAssertEqual(error as? FocusNameSensor.FocusNameError, .unconfigured)
        }
    }

    func testReportsActiveNameWhileFocused() throws {
        FocusName(name: "Work").save()
        setUpDependencies(activeFocusName: "Work", receivedStatus: received(isFocused: true, at: -59))

        let sensors = try hang(FocusNameSensor(request: request).sensors())
        XCTAssertEqual(sensors.count, 1)
        XCTAssertEqual(sensors[0].UniqueID, "focus_name")
        XCTAssertEqual(sensors[0].State as? String, "Work")
        XCTAssertEqual(sensors[0].Attributes?["Is focused"] as? Bool, true)
    }

    /// The bug behind #5467: iOS runs the new Focus' filter before it reports the status of the
    /// switch, and reading the status back at that moment still says nothing is running — which
    /// used to throw away the name the filter had just reported.
    func testReportsNameReportedRightBeforeAStatusSayingNothingIsRunning() throws {
        FocusName(name: "Personal").save()
        setUpDependencies(
            activeFocusName: "Personal",
            filterRan: -1,
            receivedStatus: received(isFocused: false, at: 0),
            liveIsFocused: false
        )

        let sensors = try hang(FocusNameSensor(request: request).sensors())
        XCTAssertEqual(sensors[0].State as? String, "Personal")
        XCTAssertEqual(sensors[0].Attributes?["Is focused"] as? Bool, true)
    }

    /// A Focus whose status the user doesn't share reads back as "not focused" for as long as it
    /// runs, so the name has to stand on the filter's word alone.
    func testReportsNameWhileTheLiveStatusKeepsSayingNotFocused() throws {
        FocusName(name: "Personal").save()
        setUpDependencies(activeFocusName: "Personal", liveIsFocused: false)

        let sensors = try hang(FocusNameSensor(request: request).sensors())
        XCTAssertEqual(sensors[0].State as? String, "Personal")
    }

    func testReportsNotFocusedOnceEveryFocusEnded() throws {
        FocusName(name: "Work").save()
        setUpDependencies(activeFocusName: "Work", receivedStatus: received(isFocused: false, at: -10))

        let sensors = try hang(FocusNameSensor(request: request).sensors())
        XCTAssertEqual(sensors[0].State as? String, FocusNameSensor.notFocusedState)
        XCTAssertEqual(sensors[0].Attributes?["Is focused"] as? Bool, false)
    }

    /// A Focus without a filter starting after every Focus ended must not inherit the name of the
    /// Focus before it, even though the status now says one is running again.
    func testReportsUnknownWhenAnUnpairedFocusStartsAfterTheNameWentStale() throws {
        FocusName(name: "Work").save()
        setUpDependencies(
            activeFocusName: "Work",
            receivedStatus: received(isFocused: true, at: -5, lastEnded: -10)
        )

        let sensors = try hang(FocusNameSensor(request: request).sensors())
        XCTAssertEqual(sensors[0].State as? String, FocusNameSensor.unknownState)
        XCTAssertEqual(sensors[0].Attributes?["Is focused"] as? Bool, true)
    }

    /// A configured name with nothing reported yet: the user created names but hasn't paired a
    /// Focus Filter with them, so we can't tell which Focus is running.
    func testReportsUnknownWhenNoFilterReported() throws {
        FocusName(name: "Work").save()
        setUpDependencies(activeFocusName: nil, receivedStatus: received(isFocused: true, at: -5))

        let sensors = try hang(FocusNameSensor(request: request).sensors())
        XCTAssertEqual(sensors[0].State as? String, FocusNameSensor.unknownState)
    }

    /// iOS sending a status without saying whether a Focus is running is not the same as saying
    /// none is, so the reported name has to survive it.
    func testKeepsTheNameWhenTheReceivedStatusIsUnknown() throws {
        FocusName(name: "Work").save()
        setUpDependencies(activeFocusName: "Work", receivedStatus: received(isFocused: nil, at: -5))

        let sensors = try hang(FocusNameSensor(request: request).sensors())
        XCTAssertEqual(sensors[0].State as? String, "Work")
    }

    /// Without the Focus status permission nothing can tell us a Focus ended, so the filter's own
    /// report is all there is — and it only ever runs when a Focus starts.
    func testReportsNameWithoutFocusAuthorization() throws {
        setUpDependencies(activeFocusName: "Sleep", focusAuthorization: .denied)

        let sensors = try hang(FocusNameSensor(request: request).sensors())
        XCTAssertEqual(sensors[0].State as? String, "Sleep")
        XCTAssertEqual(sensors[0].Attributes?["Is focused"] as? Bool, true)
    }

    func testReportsUnknownWithoutAuthorizationAndWithoutAnyReport() throws {
        FocusName(name: "Sleep").save()
        setUpDependencies(activeFocusName: nil, focusAuthorization: .denied)

        let sensors = try hang(FocusNameSensor(request: request).sensors())
        XCTAssertEqual(sensors[0].State as? String, FocusNameSensor.unknownState)
        XCTAssertNil(sensors[0].Attributes?["Is focused"])
    }

    func testReportsNameWhenFocusStatusUnavailable() throws {
        setUpDependencies(activeFocusName: "Sleep", focusAvailable: false)

        let sensors = try hang(FocusNameSensor(request: request).sensors())
        XCTAssertEqual(sensors[0].State as? String, "Sleep")
    }

    /// The received status is what every process reads back, so it has to survive the one that
    /// received it going away — and it has to remember when a Focus last ended.
    func testReceivedStatusIsStoredWithWhenEveryFocusLastEnded() throws {
        Current.isAppExtension = true

        Current.focusStatus.update(fromReceived: INFocusStatus(isFocused: false))
        XCTAssertEqual(Current.focusStatus.lastReceived()?.isFocused, false)
        XCTAssertEqual(Current.focusStatus.lastReceived()?.lastEndedDate, now)

        Current.date = { [now] in now.addingTimeInterval(60) }
        Current.focusStatus.update(fromReceived: INFocusStatus(isFocused: true))
        XCTAssertEqual(Current.focusStatus.lastReceived()?.isFocused, true)
        XCTAssertEqual(Current.focusStatus.lastReceived()?.lastEndedDate, now)
    }

    /// A received status must not destroy the reported name: whether it is still current depends on
    /// when the filter ran, which is only known when the two are read back together.
    func testReceivedStatusKeepsTheReportedName() throws {
        Current.isAppExtension = true
        Current.focusFilter.setActiveFocusName("Work")

        Current.focusStatus.update(fromReceived: INFocusStatus(isFocused: false))

        XCTAssertEqual(Current.focusFilter.activeFocusName(), "Work")
    }
}
