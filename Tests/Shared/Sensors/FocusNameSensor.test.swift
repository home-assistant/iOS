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

        let previousIsTestFlight = Current.isTestFlight
        addTeardownBlock { Current.isTestFlight = previousIsTestFlight }
        Current.isTestFlight = true
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
        lastEnded: TimeInterval? = nil,
        lastStarted: TimeInterval? = nil
    ) -> FocusStatusState {
        let date = now.addingTimeInterval(offset)
        return FocusStatusState(
            isFocused: isFocused,
            date: date,
            lastEndedDate: lastEnded.map { now.addingTimeInterval($0) } ?? (isFocused == false ? date : nil),
            lastStartedDate: lastStarted.map { now.addingTimeInterval($0) } ?? (isFocused == true ? date : nil)
        )
    }

    func testUnconfiguredWithoutNamesOrActiveName() throws {
        setUpDependencies(activeFocusName: nil, liveIsFocused: true)

        let promise = FocusNameSensor(request: request).sensors()
        XCTAssertThrowsError(try hang(promise)) { error in
            XCTAssertEqual(error as? FocusNameSensor.FocusNameError, .unconfigured)
        }
    }

    func testUnavailableOutsideTestFlight() throws {
        Current.isTestFlight = false
        FocusName(name: "Work").save()
        setUpDependencies(activeFocusName: "Work", receivedStatus: received(isFocused: true, at: -59))

        let promise = FocusNameSensor(request: request).sensors()
        XCTAssertThrowsError(try hang(promise)) { error in
            XCTAssertEqual(error as? FocusNameSensor.FocusNameError, .unavailable)
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

    /// The filter runs in an app iOS often has to launch in the background first, so the status of
    /// the Focus that ended can be processed well after it: inside the switch window the name the
    /// filter just reported still stands.
    func testKeepsTheNameWhenTheEndedStatusIsProcessedLongAfterTheFilterRun() throws {
        FocusName(name: "Sleep").save()
        setUpDependencies(
            activeFocusName: "Sleep",
            filterRan: -20,
            receivedStatus: received(isFocused: false, at: 0),
            liveIsFocused: false
        )

        let sensors = try hang(FocusNameSensor(request: request).sensors())
        XCTAssertEqual(sensors[0].State as? String, "Sleep")
        XCTAssertEqual(sensors[0].Attributes?["Is focused"] as? Bool, true)
    }

    /// Knowing every Focus ended blanks the name rather than reporting a made-up state.
    func testReportsEmptyOnceEveryFocusEnded() throws {
        FocusName(name: "Work").save()
        setUpDependencies(
            activeFocusName: "Work",
            receivedStatus: received(isFocused: false, at: -10, lastStarted: -50)
        )

        let sensors = try hang(FocusNameSensor(request: request).sensors())
        XCTAssertEqual(sensors[0].State as? String, "")
        XCTAssertEqual(sensors[0].Attributes?["Is focused"] as? Bool, false)
    }

    /// The bug behind #5592: Focus status is shared per Focus, and the ones the user doesn't share
    /// read back as "not focused" the whole time they run. Nothing ever confirmed this Focus, so
    /// those statuses can't be what ended it — only the filter's own reset run can.
    func testKeepsTheNameWhenTheEndedStatusNeverSawTheFocusStart() throws {
        FocusName(name: "Work").save()
        setUpDependencies(
            activeFocusName: "Work",
            filterRan: -3600,
            receivedStatus: received(isFocused: false, at: -60),
            liveIsFocused: false
        )

        let sensors = try hang(FocusNameSensor(request: request).sensors())
        XCTAssertEqual(sensors[0].State as? String, "Work")
        XCTAssertEqual(sensors[0].Attributes?["Is focused"] as? Bool, true)
    }

    /// A confirmation stamped at the same instant as the filter run belongs to that run: the two
    /// come from different processes reading the same clock, so the boundary counts as seen.
    func testReportsEmptyWhenTheFocusWasConfirmedAtTheFilterRunInstant() throws {
        FocusName(name: "Work").save()
        setUpDependencies(
            activeFocusName: "Work",
            receivedStatus: received(isFocused: false, at: -10, lastStarted: -60)
        )

        let sensors = try hang(FocusNameSensor(request: request).sensors())
        XCTAssertEqual(sensors[0].State as? String, "")
        XCTAssertEqual(sensors[0].Attributes?["Is focused"] as? Bool, false)
    }

    /// Switching from a Focus iOS could see to one it can't: the confirmation belongs to the Focus
    /// that ended, so it must not hand the statuses that follow the right to end the new one.
    func testKeepsTheNameWhenOnlyThePreviousFocusWasEverConfirmed() throws {
        FocusName(name: "Work").save()
        setUpDependencies(
            activeFocusName: "Work",
            filterRan: -3600,
            receivedStatus: received(isFocused: false, at: -60, lastStarted: -3610),
            liveIsFocused: false
        )

        let sensors = try hang(FocusNameSensor(request: request).sensors())
        XCTAssertEqual(sensors[0].State as? String, "Work")
        XCTAssertEqual(sensors[0].Attributes?["Is focused"] as? Bool, true)
    }

    /// A Focus without a filter starting after every Focus ended keeps the last reported name —
    /// it's the best answer we have, and "Is focused" carries what's actually known.
    func testKeepsTheNameWhenAnUnpairedFocusStartsAfterTheFilterWentStale() throws {
        FocusName(name: "Work").save()
        setUpDependencies(
            activeFocusName: "Work",
            receivedStatus: received(isFocused: true, at: -5, lastEnded: -10)
        )

        let sensors = try hang(FocusNameSensor(request: request).sensors())
        XCTAssertEqual(sensors[0].State as? String, "Work")
        XCTAssertEqual(sensors[0].Attributes?["Is focused"] as? Bool, true)
    }

    /// When a Focus deactivates, iOS re-runs the filter with no name picked and pushes that no
    /// Focus is running: the sensor blanks, but the name it knew survives underneath.
    func testReportsEmptyWhenTheFilterResetsOnDeactivation() throws {
        FocusName(name: "Personal").save()
        setUpDependencies(activeFocusName: nil, receivedStatus: received(isFocused: false, at: 0))
        Current.focusFilter.activeFocusState = { [now] in
            FocusFilterState(name: nil, date: now, lastKnownName: "Personal")
        }

        let sensors = try hang(FocusNameSensor(request: request).sensors())
        XCTAssertEqual(sensors[0].State as? String, "")
        XCTAssertEqual(sensors[0].Attributes?["Is focused"] as? Bool, false)
    }

    /// iOS skips re-running the filter when the same Focus quickly reactivates — the pushed status
    /// is the only signal — so the name it wiped on deactivation has to come back on its own.
    func testRestoresTheNameWhenFocusReactivatesWithoutAFilterRun() throws {
        FocusName(name: "Personal").save()
        setUpDependencies(
            activeFocusName: nil,
            receivedStatus: received(isFocused: true, at: -1, lastEnded: -10)
        )
        Current.focusFilter.activeFocusState = { [now] in
            FocusFilterState(name: nil, date: now.addingTimeInterval(-11), lastKnownName: "Personal")
        }

        let sensors = try hang(FocusNameSensor(request: request).sensors())
        XCTAssertEqual(sensors[0].State as? String, "Personal")
        XCTAssertEqual(sensors[0].Attributes?["Is focused"] as? Bool, true)
    }

    /// Names created but no filter has ever reported one: the sensor must still register — an
    /// error would drop it from the sensors list — reporting empty, never a made-up state.
    func testReportsEmptyWhenNoFilterEverReported() throws {
        FocusName(name: "Work").save()
        setUpDependencies(activeFocusName: nil, receivedStatus: received(isFocused: true, at: -5))

        let sensors = try hang(FocusNameSensor(request: request).sensors())
        XCTAssertEqual(sensors[0].State as? String, "")
        XCTAssertEqual(sensors[0].Attributes?["Is focused"] as? Bool, true)
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

    func testReportsEmptyWithoutAuthorizationAndWithoutAnyReport() throws {
        FocusName(name: "Sleep").save()
        setUpDependencies(activeFocusName: nil, focusAuthorization: .denied)

        let sensors = try hang(FocusNameSensor(request: request).sensors())
        XCTAssertEqual(sensors[0].State as? String, "")
        XCTAssertNil(sensors[0].Attributes?["Is focused"])
    }

    func testReportsNameWhenFocusStatusUnavailable() throws {
        setUpDependencies(activeFocusName: "Sleep", focusAvailable: false)

        let sensors = try hang(FocusNameSensor(request: request).sensors())
        XCTAssertEqual(sensors[0].State as? String, "Sleep")
    }

    /// The received status is what every process reads back, so it has to survive the one that
    /// received it going away — and it has to remember when a Focus last started and last ended,
    /// which is what pairs a status with the Focus it is talking about.
    func testReceivedStatusIsStoredWithWhenAFocusLastStartedAndEnded() throws {
        Current.isAppExtension = true

        Current.focusStatus.update(fromReceived: INFocusStatus(isFocused: false))
        XCTAssertEqual(Current.focusStatus.lastReceived()?.isFocused, false)
        XCTAssertEqual(Current.focusStatus.lastReceived()?.lastEndedDate, now)

        Current.date = { [now] in now.addingTimeInterval(60) }
        Current.focusStatus.update(fromReceived: INFocusStatus(isFocused: true))
        XCTAssertEqual(Current.focusStatus.lastReceived()?.isFocused, true)
        XCTAssertEqual(Current.focusStatus.lastReceived()?.lastEndedDate, now)
        XCTAssertEqual(Current.focusStatus.lastReceived()?.lastStartedDate, now.addingTimeInterval(60))

        Current.date = { [now] in now.addingTimeInterval(120) }
        Current.focusStatus.update(fromReceived: INFocusStatus(isFocused: false))
        XCTAssertEqual(Current.focusStatus.lastReceived()?.lastEndedDate, now.addingTimeInterval(120))
        XCTAssertEqual(Current.focusStatus.lastReceived()?.lastStartedDate, now.addingTimeInterval(60))
    }

    /// Status persisted before it recorded when a Focus started still says one was running, and
    /// that is the confirmation — otherwise the first status after an upgrade could never be the
    /// one that ends the Focus it was talking about.
    func testReceivedStatusBackfillsTheStartFromAPersistedFocusedStatus() throws {
        Current.isAppExtension = true
        Current.focusStatus.receivedStatus.value = FocusStatusState(
            isFocused: true,
            date: now.addingTimeInterval(-60),
            lastEndedDate: nil
        )

        Current.focusStatus.update(fromReceived: INFocusStatus(isFocused: false))

        XCTAssertEqual(Current.focusStatus.lastReceived()?.lastEndedDate, now)
        XCTAssertEqual(Current.focusStatus.lastReceived()?.lastStartedDate, now.addingTimeInterval(-60))
    }

    /// A received status must not destroy the reported name: whether it is still current depends on
    /// when the filter ran, which is only known when the two are read back together.
    func testReceivedStatusKeepsTheReportedName() throws {
        Current.isAppExtension = true
        Current.focusFilter.setActiveFocusName("Work")

        Current.focusStatus.update(fromReceived: INFocusStatus(isFocused: false))

        XCTAssertEqual(Current.focusFilter.activeFocusName(), "Work")
    }

    /// The filter's nil-name reset run on deactivation carries the last known name forward, since
    /// iOS won't re-run the filter when the same Focus quickly reactivates.
    func testFilterResetCarriesTheLastKnownNameForward() throws {
        Current.focusFilter.setActiveFocusName("Work")
        Current.date = { [now] in now.addingTimeInterval(FocusFilterWrapper.resetGracePeriod + 1) }
        Current.focusFilter.setActiveFocusName(nil)

        XCTAssertNil(Current.focusFilter.state.value?.name)
        XCTAssertEqual(Current.focusFilter.state.value?.lastKnownName, "Work")

        Current.focusFilter.setActiveFocusName("Sleep")
        XCTAssertEqual(Current.focusFilter.state.value?.lastKnownName, "Sleep")
    }

    /// Switching Focus runs the ending Focus' reset pass and the starting Focus' named pass around
    /// the same moment and in no guaranteed order, so a reset landing second must not erase the
    /// name the switch just reported.
    func testFilterResetRightAfterANamedRunIsIgnored() throws {
        Current.focusFilter.setActiveFocusName("Sleep")
        Current.date = { [now] in now.addingTimeInterval(FocusFilterWrapper.resetGracePeriod - 1) }
        Current.focusFilter.setActiveFocusName(nil)

        XCTAssertEqual(Current.focusFilter.state.value?.name, "Sleep")
        XCTAssertEqual(Current.focusFilter.state.value?.date, now)
    }

    /// A name the user deleted has to stop being reported, including through the sticky copy the
    /// nil-name runs fall back to.
    func testForgetFocusNameClearsTheNameAndTheLastKnownOne() throws {
        Current.focusFilter.setActiveFocusName("Work")
        Current.focusFilter.forgetFocusName("Work")

        XCTAssertNil(Current.focusFilter.state.value?.name)
        XCTAssertNil(Current.focusFilter.state.value?.lastKnownName)
    }

    func testForgetFocusNameKeepsAnUnrelatedName() throws {
        Current.focusFilter.setActiveFocusName("Work")
        Current.focusFilter.forgetFocusName("Sleep")

        XCTAssertEqual(Current.focusFilter.state.value?.name, "Work")
        XCTAssertEqual(Current.focusFilter.state.value?.lastKnownName, "Work")
    }
}
