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

    /// Holds a reader until the test lets it answer, whether or not its task is cancelled.
    private final class Gate {
        private let lock = NSLock()
        private var isOpen = false
        private var waiters = [CheckedContinuation<Void, Never>]()

        func wait() async {
            await withCheckedContinuation { continuation in
                lock.lock()
                if isOpen {
                    lock.unlock()
                    continuation.resume()
                } else {
                    waiters.append(continuation)
                    lock.unlock()
                }
            }
        }

        func open() {
            lock.lock()
            isOpen = true
            let waiting = waiters
            waiters = []
            lock.unlock()
            waiting.forEach { $0.resume() }
        }
    }

    /// Counts how many times iOS was asked, from whichever thread asked.
    private final class Calls {
        private let lock = NSLock()
        private var value = 0

        var count: Int {
            lock.lock()
            defer { lock.unlock() }
            return value
        }

        func record() {
            lock.lock()
            value += 1
            lock.unlock()
        }
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        try clearFocusNames()
        resetFocusState()
        Current.date = { [now] in now }

        let previousTimeout = FocusFilterWrapper.currentValuesTimeout
        addTeardownBlock { FocusFilterWrapper.currentValuesTimeout = previousTimeout }
        setUpIOS(liveIsFocused: nil)
    }

    override func tearDownWithError() throws {
        try clearFocusNames()
        resetFocusState()
        Current.isAppExtension = false
        Current.date = Date.init
        try super.tearDownWithError()
    }

    private func clearFocusNames() throws {
        try Current.database().write { db in
            _ = try FocusName.deleteAll(db)
        }
    }

    private func resetFocusState() {
        Current.focusFilter = FocusFilterWrapper()
        Current.focusStatus = FocusStatusWrapper()
        Current.focusFilter.runs.value = nil
        Current.focusFilter.readings.value = nil
        Current.focusStatus.pushes.value = nil
        Current.focusStatus.readings.value = nil
    }

    private func setUpIOS(
        canAskIOS: Bool = true,
        authorization: FocusStatusWrapper.AuthorizationStatus = .authorized,
        liveIsFocused: Bool?
    ) {
        Current.focusStatus.canAskIOS = { canAskIOS }
        Current.focusStatus.authorizationStatus = { authorization }
        Current.focusStatus.liveIsFocused = { liveIsFocused }
    }

    private func run(_ name: String?, at offset: TimeInterval) {
        Current.focusFilter.runs.value = FocusFilterState(name: name, date: now.addingTimeInterval(offset))
    }

    private func report() throws -> (state: String?, isFocused: Bool?) {
        let sensors = try hang(FocusNameSensor(request: request).sensors())
        XCTAssertEqual(sensors.count, 1)
        XCTAssertEqual(sensors.first?.UniqueID, WebhookSensorId.focusName.rawValue)
        return (sensors.first?.State as? String, sensors.first?.Attributes?["Is focused"] as? Bool)
    }

    // MARK: - The sensor

    /// The sensor's detail screen is the only route to the Focus names, so it has to be in the
    /// list before the first one is created or a new user can never get there.
    func testReportsEmptyStateWithoutNamesOrRuns() throws {
        setUpIOS(liveIsFocused: true)

        let report = try report()
        XCTAssertEqual(report.state, "")
        XCTAssertEqual(report.isFocused, true)
    }

    func testReportsTheNameOfTheRunningFocus() throws {
        run("Work", at: -60)
        setUpIOS(liveIsFocused: true)

        let report = try report()
        XCTAssertEqual(report.state, "Work")
        XCTAssertEqual(report.isFocused, true)
    }

    /// A Focus whose status the user doesn't share reads back as "not focused" for as long as it
    /// runs, so the name stands on the filter's word alone.
    func testReportsTheNameWhileTheStatusSaysNotFocused() throws {
        run("Personal", at: -3600)
        Current.focusStatus.pushes.value = FocusStatusObservation(isFocused: false, date: now.addingTimeInterval(-60))
        setUpIOS(liveIsFocused: false)

        let report = try report()
        XCTAssertEqual(report.state, "Personal")
        XCTAssertEqual(report.isFocused, true)
    }

    /// The bug behind #5467: switching Focus performs the new Focus' filter around when iOS pushes
    /// the status of the one that ended. Neither can take the other's half away.
    func testReportsTheNameRunRightAroundAPushSayingNotFocused() throws {
        run("Sleep", at: -1)
        Current.focusStatus.pushes.value = FocusStatusObservation(isFocused: false, date: now)
        setUpIOS(canAskIOS: false, liveIsFocused: nil)

        let report = try report()
        XCTAssertEqual(report.state, "Sleep")
        XCTAssertEqual(report.isFocused, true)
    }

    /// When a Focus ends, iOS performs the filter with no name and the status says not focused.
    func testReportsEmptyOnceTheFocusEnded() throws {
        run("Work", at: -3600)
        run(nil, at: -10)
        setUpIOS(liveIsFocused: false)

        let report = try report()
        XCTAssertEqual(report.state, "")
        XCTAssertEqual(report.isFocused, false)
    }

    /// The bug behind #5921: a Focus without a filter starting after a named one ended is on, but
    /// isn't the Focus that reported the name.
    func testReportsEmptyWhileAFocusWithoutAFilterIsOn() throws {
        run(nil, at: -10)
        setUpIOS(liveIsFocused: true)

        let report = try report()
        XCTAssertEqual(report.state, "")
        XCTAssertEqual(report.isFocused, true)
    }

    /// The log behind this rewrite: Personal was on all evening, but a pushed "not focused" from
    /// hours earlier, once the app read "focused" from iOS, was taken as Personal having ended,
    /// and the name blanked while the Focus was still on. Nothing but the filter ends a name.
    func testTheStatusNeverEndsANamedFocus() throws {
        run("Personal", at: -9 * 3600)
        Current.focusStatus.pushes.value = FocusStatusObservation(isFocused: false, date: now.addingTimeInterval(-3600))
        setUpIOS(liveIsFocused: true)

        let report = try report()
        XCTAssertEqual(report.state, "Personal")
        XCTAssertEqual(report.isFocused, true)
    }

    func testReportsTheNameWithoutTheFocusStatusPermission() throws {
        run("Sleep", at: -60)
        setUpIOS(authorization: .denied, liveIsFocused: nil)

        let report = try report()
        XCTAssertEqual(report.state, "Sleep")
        XCTAssertEqual(report.isFocused, true)
    }

    func testOmitsIsFocusedWhenNothingSays() throws {
        run(nil, at: -60)
        setUpIOS(authorization: .denied, liveIsFocused: nil)

        let report = try report()
        XCTAssertEqual(report.state, "")
        XCTAssertNil(report.isFocused)
    }

    /// A filter run is what changes the name, so it signals the sensor. Only enabled sensors are
    /// observed, and enablement is per server.
    @MainActor
    func testSignalerFiresOnFilterRun() async throws {
        let previousServers = Current.servers
        addTeardownBlock {
            SensorEnablementStore.resetForTesting()
            Current.servers = previousServers
        }
        let servers = FakeServerManager()
        servers.addFake()
        Current.servers = servers
        SensorEnablementStore.resetForTesting()
        Current.sensors.setEnabledForAllServers(true, forUniqueIDs: [WebhookSensorId.focusName.rawValue])
        _ = Current.sensors.sensors(reason: .registration, server: ServerFixture.standard)

        let observationExpectation = expectation(description: "Observation")
        let signalExpectation = expectation(description: "Signal")
        let signaler = FocusNameSensorUpdateSignaler(signal: {
            signalExpectation.fulfill()
        })
        signaler.notifyObservation = {
            observationExpectation.fulfill()
        }

        await fulfillment(of: [observationExpectation], timeout: 30)

        Current.focusFilter.runs.value = FocusFilterState(name: "Personal", date: Date())

        await fulfillment(of: [signalExpectation], timeout: 30)
        signaler.stopObserving()
    }

    /// A push changes "Is focused", which keeps the sensor on screen current when the binary
    /// sensor is off, but only in the foreground: in the background the Intents extension that
    /// received it reports it.
    @MainActor
    func testSignalerFiresOnAPushOnlyInTheForeground() async throws {
        let previousServers = Current.servers
        let previousIsForegroundApp = Current.isForegroundApp
        addTeardownBlock {
            SensorEnablementStore.resetForTesting()
            Current.servers = previousServers
            Current.isForegroundApp = previousIsForegroundApp
        }
        let servers = FakeServerManager()
        servers.addFake()
        Current.servers = servers
        SensorEnablementStore.resetForTesting()
        Current.sensors.setEnabledForAllServers(true, forUniqueIDs: [WebhookSensorId.focusName.rawValue])
        _ = Current.sensors.sensors(reason: .registration, server: ServerFixture.standard)

        let observationExpectation = expectation(description: "Observation")
        let signalExpectation = expectation(description: "Signal")
        let signaler = FocusNameSensorUpdateSignaler(signal: {
            signalExpectation.fulfill()
        })
        signaler.notifyObservation = {
            observationExpectation.fulfill()
        }

        await fulfillment(of: [observationExpectation], timeout: 30)

        Current.isForegroundApp = { false }
        Current.focusStatus.pushes.value = FocusStatusObservation(isFocused: true, date: Date())
        Current.isForegroundApp = { true }
        Current.focusStatus.pushes.value = FocusStatusObservation(isFocused: false, date: Date())

        await fulfillment(of: [signalExpectation], timeout: 30)
        signaler.stopObserving()
    }

    // MARK: - The filter's current values

    /// The run with no name for a Focus that ended while iOS didn't launch the app never lands.
    /// Asking iOS for the filter's current values ends the name anyway.
    func testCurrentValuesEndANameWhoseRunWithNoNameNeverLanded() throws {
        run("Personal", at: -6 * 3600)
        Current.focusFilter.setCurrentValuesReader { nil }
        setUpIOS(liveIsFocused: false)

        let report = try report()
        XCTAssertEqual(report.state, "")
        XCTAssertEqual(report.isFocused, false)
        XCTAssertEqual(Current.focusFilter.readings.value, FocusFilterState(name: nil, date: now))
    }

    /// A Focus that turned on while iOS didn't launch the app to perform the filter is named once
    /// the app asks.
    func testCurrentValuesNameAFocusWhoseRunNeverLanded() throws {
        Current.focusFilter.setCurrentValuesReader { "Cinema" }
        setUpIOS(liveIsFocused: false)

        let report = try report()
        XCTAssertEqual(report.state, "Cinema")
        XCTAssertEqual(report.isFocused, true)
    }

    /// The app's reading is stored, so an extension, which can't ask, reports the same name.
    func testAnExtensionReportsTheNameTheAppLastRead() throws {
        run("Personal", at: -6 * 3600)
        Current.focusFilter.readings.value = FocusFilterState(name: nil, date: now.addingTimeInterval(-60))
        setUpIOS(canAskIOS: false, liveIsFocused: nil)

        XCTAssertEqual(try report().state, "")
    }

    /// A run newer than the app's last reading is the newer answer.
    func testARunNewerThanTheLastReadingIsTheName() throws {
        Current.focusFilter.readings.value = FocusFilterState(name: "Work", date: now.addingTimeInterval(-60))
        run("Sleep", at: -1)

        XCTAssertEqual(try report().state, "Sleep")
    }

    /// iOS failing to answer is not an answer: the runs keep the name, and nothing is stored.
    func testAFailedReadingLeavesTheNameToTheRuns() throws {
        struct ReadFailed: Error {}
        run("Work", at: -60)
        Current.focusFilter.setCurrentValuesReader { throw ReadFailed() }

        XCTAssertEqual(try report().state, "Work")
        XCTAssertNil(Current.focusFilter.readings.value)
    }

    /// A reading that never comes back must not hold the sensor update hostage.
    func testASlowReadingIsGivenUpOn() throws {
        FocusFilterWrapper.currentValuesTimeout = 0.05
        run("Work", at: -60)
        Current.focusFilter.setCurrentValuesReader {
            try await Task.sleep(nanoseconds: 2_000_000_000)
            return nil
        }

        XCTAssertEqual(try report().state, "Work")
        XCTAssertNil(Current.focusFilter.readings.value)
    }

    // MARK: - Runs

    /// The run with no name iOS makes when a Focus ends clears the name, and the next named run
    /// replaces it.
    func testRunWithNoNameClearsTheName() throws {
        Current.focusFilter.setActiveFocusName("Work")
        let resetDate = now.addingTimeInterval(FocusFilterWrapper.resetGracePeriod + 1)
        Current.date = { resetDate }
        Current.focusFilter.setActiveFocusName(nil)

        XCTAssertEqual(Current.focusFilter.runs.value, FocusFilterState(name: nil, date: resetDate))

        Current.focusFilter.setActiveFocusName("Sleep")
        XCTAssertEqual(Current.focusFilter.activeFocusName(), "Sleep")
    }

    /// An empty name is no name.
    func testRunWithAnEmptyNameIsARunWithNoName() throws {
        Current.focusFilter.setActiveFocusName("")

        XCTAssertEqual(Current.focusFilter.runs.value, FocusFilterState(name: nil, date: now))
    }

    /// Switching Focus can perform the filter for the starting Focus and the ending one around the
    /// same moment and in no guaranteed order, so a run with no name landing second must not
    /// erase the name the switch just reported.
    func testRunWithNoNameRightAfterANamedRunIsIgnored() throws {
        Current.focusFilter.setActiveFocusName("Sleep")
        Current.date = { [now] in now.addingTimeInterval(FocusFilterWrapper.resetGracePeriod - 1) }
        Current.focusFilter.setActiveFocusName(nil)

        XCTAssertEqual(Current.focusFilter.runs.value, FocusFilterState(name: "Sleep", date: now))
    }

    /// A name the user deleted has to stop being reported, whichever answer carried it.
    func testForgetFocusNameClearsTheName() throws {
        Current.focusFilter.setActiveFocusName("Work")
        Current.focusFilter.readings.value = FocusFilterState(name: "Work", date: now)
        Current.focusFilter.forgetFocusName("Work")

        XCTAssertNil(Current.focusFilter.runs.value?.name)
        XCTAssertNil(Current.focusFilter.readings.value?.name)
        XCTAssertNil(Current.focusFilter.activeFocusName())
    }

    func testForgetFocusNameKeepsAnUnrelatedName() throws {
        Current.focusFilter.setActiveFocusName("Work")
        Current.focusFilter.readings.value = FocusFilterState(name: "Work", date: now)
        Current.focusFilter.forgetFocusName("Sleep")

        XCTAssertEqual(Current.focusFilter.runs.value?.name, "Work")
        XCTAssertEqual(Current.focusFilter.readings.value?.name, "Work")
    }

    /// Deleting the name an older answer carried must not outrank a newer answer about another
    /// Focus, in either direction.
    func testForgettingAnOlderNameKeepsTheNewerAnswer() throws {
        run("Work", at: -60)
        Current.focusFilter.readings.value = FocusFilterState(name: "Sleep", date: now.addingTimeInterval(-10))
        Current.focusFilter.forgetFocusName("Work")

        XCTAssertEqual(Current.focusFilter.runs.value, FocusFilterState(name: nil, date: now.addingTimeInterval(-60)))
        XCTAssertEqual(Current.focusFilter.activeFocusName(), "Sleep")

        run("Sleep", at: -10)
        Current.focusFilter.readings.value = FocusFilterState(name: "Work", date: now.addingTimeInterval(-60))
        Current.focusFilter.forgetFocusName("Work")

        XCTAssertEqual(
            Current.focusFilter.readings.value,
            FocusFilterState(name: nil, date: now.addingTimeInterval(-60))
        )
        XCTAssertEqual(Current.focusFilter.activeFocusName(), "Sleep")
    }

    // MARK: - Asking iOS

    /// iOS can answer a question asked before a filter run after that run landed. The answer is
    /// dated when it was asked, so the run stays the newer of the two.
    func testAnAnswerAskedBeforeARunDoesNotOutrankIt() async throws {
        let gate = Gate()
        let asked = expectation(description: "iOS asked")
        Current.focusFilter.setCurrentValuesReader {
            asked.fulfill()
            await gate.wait()
            return nil
        }

        let reading = Task { await Current.focusFilter.readFromIOS() }
        await fulfillment(of: [asked], timeout: 30)
        Current.date = { [now] in now.addingTimeInterval(1) }
        Current.focusFilter.setActiveFocusName("Work")
        gate.open()
        await reading.value

        XCTAssertEqual(Current.focusFilter.readings.value, FocusFilterState(name: nil, date: now))
        XCTAssertEqual(Current.focusFilter.activeFocusName(), "Work")
    }

    /// Both Focus sensors read at once. They share one question, so neither can store an older
    /// answer over the other's.
    func testReadsWhileAQuestionIsInFlightShareIt() async throws {
        let gate = Gate()
        let calls = Calls()
        let reader: FocusFilterWrapper.CurrentValuesReader = {
            calls.record()
            await gate.wait()
            return "Work"
        }

        let first = try XCTUnwrap(Current.focusFilter.currentRequest(asking: reader))
        let second = try XCTUnwrap(Current.focusFilter.currentRequest(asking: reader))
        XCTAssertEqual(first.id, second.id)

        gate.open()
        _ = await first.answer.value
        XCTAssertEqual(calls.count, 1)

        // Answered, so the next read asks again.
        let third = try XCTUnwrap(Current.focusFilter.currentRequest(asking: reader))
        XCTAssertNotEqual(third.id, first.id)
        _ = await third.answer.value
        XCTAssertEqual(calls.count, 2)
    }

    /// A question iOS doesn't answer in time is cancelled, and the next read asks again once the
    /// cancelled one has stopped.
    func testATimedOutQuestionIsCancelled() async throws {
        FocusFilterWrapper.currentValuesTimeout = 0.05
        let calls = Calls()
        let cancelled = expectation(description: "question cancelled")
        Current.focusFilter.setCurrentValuesReader {
            calls.record()
            do {
                try await Task.sleep(nanoseconds: 30_000_000_000)
            } catch {
                cancelled.fulfill()
                throw error
            }
            return "Work"
        }

        await Current.focusFilter.readFromIOS()
        await fulfillment(of: [cancelled], timeout: 30)
        XCTAssertEqual(calls.count, 1)

        FocusFilterWrapper.currentValuesTimeout = 30
        Current.focusFilter.setCurrentValuesReader { "Sleep" }
        let askedAgain = expectation(for: NSPredicate { _, _ in
            Task { await Current.focusFilter.readFromIOS() }
            return Current.focusFilter.readings.value?.name == "Sleep"
        }, evaluatedWith: nil)
        await fulfillment(of: [askedAgain], timeout: 30)
    }

    /// A question that ignores being cancelled and never comes back must not gain a sibling on
    /// every read: until iOS answers it, reads go without asking.
    func testNoNewQuestionWhileATimedOutOneIsUnanswered() async throws {
        FocusFilterWrapper.currentValuesTimeout = 0.05
        let gate = Gate()
        let calls = Calls()
        let answered = expectation(description: "the stuck question answered")
        answered.assertForOverFulfill = false
        Current.focusFilter.setCurrentValuesReader {
            calls.record()
            await gate.wait()
            answered.fulfill()
            return nil
        }

        await Current.focusFilter.readFromIOS()
        await Current.focusFilter.readFromIOS()
        XCTAssertEqual(calls.count, 1)
        XCTAssertNil(Current.focusFilter.readings.value, "the stuck answer comes too late to be stored")

        gate.open()
        await fulfillment(of: [answered], timeout: 30)
        let cleared = expectation(for: NSPredicate { _, _ in
            Task { await Current.focusFilter.readFromIOS() }
            return calls.count > 1
        }, evaluatedWith: nil)
        await fulfillment(of: [cleared], timeout: 30)
    }

    // MARK: - Pushes

    /// The push is stored with when it arrived, which is what orders it against the app's reading.
    func testAPushIsStoredWithWhenItArrived() throws {
        Current.isAppExtension = true

        Current.focusStatus.record(pushed: INFocusStatus(isFocused: false))
        XCTAssertEqual(Current.focusStatus.pushes.value, FocusStatusObservation(isFocused: false, date: now))

        Current.date = { [now] in now.addingTimeInterval(60) }
        Current.focusStatus.record(pushed: INFocusStatus(isFocused: true))
        XCTAssertEqual(
            Current.focusStatus.pushes.value,
            FocusStatusObservation(isFocused: true, date: now.addingTimeInterval(60))
        )
    }

    /// A push without a value is skipped, as Apple's sample does.
    func testAPushWithoutAValueIsSkipped() throws {
        Current.focusStatus.pushes.value = FocusStatusObservation(isFocused: true, date: now.addingTimeInterval(-60))

        Current.focusStatus.record(pushed: INFocusStatus(isFocused: nil))
        Current.focusStatus.record(pushed: nil)

        XCTAssertEqual(
            Current.focusStatus.pushes.value,
            FocusStatusObservation(isFocused: true, date: now.addingTimeInterval(-60))
        )
    }

    /// A push only ever changes the status half.
    func testAPushKeepsTheName() throws {
        Current.focusFilter.setActiveFocusName("Work")

        Current.focusStatus.record(pushed: INFocusStatus(isFocused: false))

        XCTAssertEqual(Current.focusFilter.activeFocusName(), "Work")
    }

    // MARK: - Stored by an older build

    /// The keys predate these types and carried more fields. What an older build stored still
    /// reads, so the first report after an upgrade starts from the last thing iOS said.
    func testReadsWhatAnOlderBuildStored() throws {
        let prefs = Current.settingsStore.prefs
        prefs.set(
            Data(#"{"name":"Personal","date":721485839,"liveConfirmedDate":721513035}"#.utf8),
            forKey: "FocusFilterStateKey"
        )
        prefs.set(
            Data(#"{"isFocused":false,"date":721511049,"lastEndedDate":721511049,"lastStartedDate":719850873}"#.utf8),
            forKey: "FocusStatusStateKey"
        )

        XCTAssertEqual(
            Current.focusFilter.runs.value,
            FocusFilterState(name: "Personal", date: Date(timeIntervalSinceReferenceDate: 721_485_839))
        )
        XCTAssertEqual(
            Current.focusStatus.pushes.value,
            FocusStatusObservation(isFocused: false, date: Date(timeIntervalSinceReferenceDate: 721_511_049))
        )
    }

    // MARK: - The Intents extension

    /// The Intents extension is launched by iOS to receive the status, with no network information
    /// cached: without refreshing it first a server reachable only at home has no usable URL and
    /// the report goes nowhere while claiming success. So the refresh has to have happened by the
    /// time the Focus sensors go out.
    func testStatusIntentRefreshesNetworkInformationBeforeReporting() throws {
        Current.isAppExtension = true
        setUpIOS(canAskIOS: false, liveIsFocused: nil)
        let previousServers = Current.servers
        let previousApis = Current.cachedApis
        let previousWebhooks = Current.webhooks
        let previousRefresh = Current.connectivity.refreshNetworkInformation
        let previousSettleDelay = FocusStatusIntentHandler.settleDelay
        addTeardownBlock {
            Current.servers = previousServers
            Current.cachedApis = previousApis
            Current.webhooks = previousWebhooks
            Current.connectivity.refreshNetworkInformation = previousRefresh
            FocusStatusIntentHandler.settleDelay = previousSettleDelay
        }
        let servers = FakeServerManager()
        servers.addFake()
        Current.servers = servers
        Current.cachedApis = [:]
        FocusStatusIntentHandler.settleDelay = 0

        var refreshed = false
        Current.connectivity.refreshNetworkInformation = { refreshed = true }

        let sent = expectation(description: "focus sensors reported")
        var refreshedBeforeReporting: Bool?
        let webhooks = FakeWebhookManager()
        webhooks.sendRequestHandler = { _, _, request, seal in
            if request.type == "update_sensor_states" {
                refreshedBeforeReporting = refreshed
                sent.fulfill()
            }
            seal.fulfill(())
        }
        Current.webhooks = webhooks

        let completed = expectation(description: "intent handled")
        FocusStatusIntentHandler().handle(
            intent: INShareFocusStatusIntent(focusStatus: INFocusStatus(isFocused: true))
        ) { response in
            XCTAssertEqual(response.code, .success)
            completed.fulfill()
        }

        wait(for: [sent, completed], timeout: 30)
        XCTAssertEqual(refreshedBeforeReporting, true)
        XCTAssertEqual(Current.focusStatus.latest()?.isFocused, true)
    }

    /// With no server to report to, the status is still stored and the intent still succeeds: the
    /// app's next update reads it back.
    func testStatusIntentSucceedsWithNoServerToReportTo() throws {
        Current.isAppExtension = true
        let previousServers = Current.servers
        let previousApis = Current.cachedApis
        let previousRefresh = Current.connectivity.refreshNetworkInformation
        let previousSettleDelay = FocusStatusIntentHandler.settleDelay
        addTeardownBlock {
            Current.servers = previousServers
            Current.cachedApis = previousApis
            Current.connectivity.refreshNetworkInformation = previousRefresh
            FocusStatusIntentHandler.settleDelay = previousSettleDelay
        }
        Current.servers = FakeServerManager(initial: 0)
        Current.cachedApis = [:]
        Current.connectivity.refreshNetworkInformation = {}
        FocusStatusIntentHandler.settleDelay = 0

        let completed = expectation(description: "intent handled")
        FocusStatusIntentHandler().handle(
            intent: INShareFocusStatusIntent(focusStatus: INFocusStatus(isFocused: false))
        ) { response in
            XCTAssertEqual(response.code, .success)
            completed.fulfill()
        }

        wait(for: [completed], timeout: 30)
        XCTAssertEqual(Current.focusStatus.pushes.value?.isFocused, false)
    }
}
