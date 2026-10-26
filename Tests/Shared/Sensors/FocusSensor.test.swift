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

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    /// Enablement is per server, so the device-level observation these cover only starts while
    /// there is a server to report to.
    private var previousServers: ServerManager!

    override func setUp() {
        super.setUp()
        previousServers = Current.servers
        let servers = FakeServerManager()
        servers.addFake()
        Current.servers = servers
        // Stated rather than inherited: the observation only runs while a server wants the sensor,
        // and what an earlier test left in the shared selection is not this test's premise.
        SensorEnablementStore.resetForTesting()
        Current.sensors.setEnabledForAllServers(true, forUniqueIDs: [
            WebhookSensorId.focus.rawValue,
        ])
        resetFocusState()
        Current.date = { [now] in now }
    }

    override func tearDown() {
        SensorEnablementStore.resetForTesting()
        Current.servers = previousServers
        resetFocusState()
        Current.date = Date.init
        super.tearDown()
    }

    private func resetFocusState() {
        Current.focusFilter = FocusFilterWrapper()
        Current.focusStatus = FocusStatusWrapper()
        Current.focusFilter.runs.value = nil
        Current.focusFilter.readings.value = nil
        Current.focusStatus.pushes.value = nil
        Current.focusStatus.readings.value = nil
    }

    /// - Parameters:
    ///   - canAskIOS: `false` for an extension, which can't read `INFocusStatusCenter`.
    ///   - liveIsFocused: what iOS answers when the app asks it.
    private func setUpIOS(
        canAskIOS: Bool = true,
        authorization: FocusStatusWrapper.AuthorizationStatus = .authorized,
        liveIsFocused: Bool?
    ) {
        Current.focusStatus.canAskIOS = { canAskIOS }
        Current.focusStatus.authorizationStatus = { authorization }
        Current.focusStatus.liveIsFocused = { liveIsFocused }
    }

    private func focusState() throws -> Any? {
        let sensors = try hang(FocusSensor(request: request).sensors())
        XCTAssertEqual(sensors.count, 1)
        let sensor = try XCTUnwrap(sensors.first(where: { $0.UniqueID == WebhookSensorId.focus.rawValue }))
        XCTAssertEqual(sensor.Type, "binary_sensor")
        return sensor.State
    }

    func testNotAvailable() throws {
        Current.focusStatus.isAvailable = { false }

        XCTAssertThrowsError(try hang(FocusSensor(request: request).sensors())) { error in
            XCTAssertEqual(error as? FocusSensor.FocusError, .unavailable)
        }
    }

    func testIsFocusedYes() throws {
        setUpIOS(liveIsFocused: true)

        let sensors = try hang(FocusSensor(request: request).sensors())
        let focusSensor = try XCTUnwrap(sensors.first(where: { $0.UniqueID == "focus" }))
        XCTAssertEqual(focusSensor.Name, "Focus")
        XCTAssertEqual(focusSensor.Icon, "mdi:moon-waning-crescent")
        XCTAssertEqual(focusSensor.Type, "binary_sensor")
        XCTAssertEqual(focusSensor.State as? Bool, true)
    }

    func testIsFocusedNo() throws {
        setUpIOS(liveIsFocused: false)

        XCTAssertEqual(try focusState() as? Bool, false)
    }

    /// Listed rather than dropped: switching it on is what asks for Focus access, so a sensor that
    /// vanished until it was granted would have no row left to switch on.
    func testNotAuthorizedReportsUnavailable() throws {
        for state: FocusStatusWrapper.AuthorizationStatus in [.restricted, .denied, .notDetermined] {
            setUpIOS(authorization: state, liveIsFocused: true)

            XCTAssertEqual(try focusState() as? String, "unavailable", "\(state)")
        }
    }

    /// iOS giving no answer is not a reason to vanish from the list: the row is the only switch.
    func testIsFocusedNilStaysListedAsUnavailable() throws {
        setUpIOS(liveIsFocused: nil)

        XCTAssertEqual(try focusState() as? String, "unavailable")
    }

    /// Every read stores what iOS answered, so the extensions that can't ask report it too.
    func testTheAppStoresWhatIOSAnswered() throws {
        setUpIOS(liveIsFocused: true)

        _ = try focusState()

        XCTAssertEqual(Current.focusStatus.readings.value, FocusStatusObservation(isFocused: true, date: now))
    }

    /// A Focus paired with the filter is on even while iOS reports "not focused", which it does for
    /// a Focus that doesn't share its status or that allows this app's notifications.
    func testNamedFocusIsOnWhateverTheStatusSays() throws {
        Current.focusFilter.runs.value = FocusFilterState(name: "Personal", date: now.addingTimeInterval(-3600))
        Current.focusStatus.pushes.value = FocusStatusObservation(isFocused: false, date: now.addingTimeInterval(-60))
        setUpIOS(liveIsFocused: false)

        XCTAssertEqual(try focusState() as? Bool, true)
    }

    /// The filter path doesn't need the Focus status permission.
    func testNamedFocusIsOnWithoutAuthorization() throws {
        Current.focusFilter.runs.value = FocusFilterState(name: "Personal", date: now.addingTimeInterval(-60))
        setUpIOS(authorization: .denied, liveIsFocused: nil)

        XCTAssertEqual(try focusState() as? Bool, true)
    }

    /// The run iOS makes with no name when a Focus ends says nothing about other Focuses: the
    /// status decides, both ways.
    func testRunWithNoNameDefersToTheStatus() throws {
        Current.focusFilter.runs.value = FocusFilterState(name: nil, date: now.addingTimeInterval(-1))

        setUpIOS(liveIsFocused: false)
        XCTAssertEqual(try focusState() as? Bool, false)

        setUpIOS(liveIsFocused: true)
        XCTAssertEqual(try focusState() as? Bool, true, "a Focus without a filter is on")
    }

    /// The bug behind #5711: iOS doesn't reliably push the status of a Focus ending, so a pushed
    /// "focused" stood until the next Focus started. The app's own reading is newer.
    func testFocusEndingWithoutAPushIsReadFromIOS() throws {
        Current.focusStatus.pushes.value = FocusStatusObservation(isFocused: true, date: now.addingTimeInterval(-36000))
        setUpIOS(liveIsFocused: false)

        XCTAssertEqual(try focusState() as? Bool, false)
    }

    /// The bug behind #5850: a pushed "not focused" from days ago outranked iOS answering that a
    /// Focus is on.
    func testStalePushedNotFocusedYieldsToIOS() throws {
        Current.focusStatus.pushes.value = FocusStatusObservation(
            isFocused: false,
            date: now.addingTimeInterval(-48 * 3600)
        )
        setUpIOS(liveIsFocused: true)

        XCTAssertEqual(try focusState() as? Bool, true)
    }

    /// The log behind this rewrite. The push provider extension, which can't ask iOS, rebuilt the
    /// sensor from a three-hour-old pushed "not focused" and reported it off, while the app had
    /// read "focused" from iOS half an hour earlier and the paired Personal Focus was still on.
    /// Every process now reports the newest answer any of them stored.
    func testAnExtensionReportsTheNewestStoredAnswerRatherThanAnOlderPush() throws {
        Current.focusStatus.pushes.value = FocusStatusObservation(
            isFocused: false,
            date: now.addingTimeInterval(-3 * 3600)
        )
        Current.focusStatus.readings.value = FocusStatusObservation(
            isFocused: true,
            date: now.addingTimeInterval(-1800)
        )
        setUpIOS(canAskIOS: false, liveIsFocused: false)

        XCTAssertEqual(try focusState() as? Bool, true)
        XCTAssertEqual(
            Current.focusStatus.readings.value?.date,
            now.addingTimeInterval(-1800),
            "an extension must not store an answer it can't get"
        )
    }

    /// The other way round: a push newer than the app's last reading is the newer answer.
    func testAnExtensionReportsAPushNewerThanTheAppsReading() throws {
        Current.focusStatus.readings.value = FocusStatusObservation(
            isFocused: true,
            date: now.addingTimeInterval(-1800)
        )
        Current.focusStatus.pushes.value = FocusStatusObservation(isFocused: false, date: now.addingTimeInterval(-60))
        setUpIOS(canAskIOS: false, liveIsFocused: nil)

        XCTAssertEqual(try focusState() as? Bool, false)
    }

    /// Without the permission iOS stops answering and pushing, so a push from before it was
    /// revoked must not keep being reported.
    func testRevokedPermissionOutranksAStalePush() throws {
        Current.focusStatus.pushes.value = FocusStatusObservation(isFocused: true, date: now.addingTimeInterval(-3600))
        setUpIOS(authorization: .denied, liveIsFocused: nil)

        XCTAssertEqual(try focusState() as? String, "unavailable")
    }

    func testUpdateSignalerCreated() throws {
        setUpIOS(liveIsFocused: false)

        let dependencies = SensorProviderDependencies()
        let provider = FocusSensor(request: .init(
            reason: .trigger("unit-test"),
            dependencies: dependencies,
            location: nil,
            serverVersion: Version()
        ))
        _ = try hang(provider.sensors())

        let signaler: FocusSensorUpdateSignaler? = dependencies.existingSignaler(for: provider)
        XCTAssertNotNil(signaler)
    }

    /// Created while nothing can be read yet too: a filter run is still what turns it on.
    func testUpdateSignalerCreatedWhileUnavailable() throws {
        setUpIOS(authorization: .denied, liveIsFocused: nil)

        let dependencies = SensorProviderDependencies()
        let provider = FocusSensor(request: .init(
            reason: .trigger("unit-test"),
            dependencies: dependencies,
            location: nil,
            serverVersion: Version()
        ))
        _ = try hang(provider.sensors())

        let signaler: FocusSensorUpdateSignaler? = dependencies.existingSignaler(for: provider)
        XCTAssertNotNil(signaler)
    }

    /// A push only signals in the foreground: in the background the Intents extension that
    /// received it reports it itself.
    @MainActor
    func testSignaler() async throws {
        setUpIOS(liveIsFocused: true)
        _ = Current.sensors.sensors(reason: .registration, server: ServerFixture.standard)

        let observationExpectation = expectation(description: "Observation")
        let signalExpectation = expectation(description: "Signal")
        let signaler = FocusSensorUpdateSignaler(signal: {
            signalExpectation.fulfill()
        })

        signaler.notifyObservation = {
            observationExpectation.fulfill()
        }

        await fulfillment(of: [observationExpectation], timeout: 10)

        let previousIsForegroundApp = Current.isForegroundApp
        addTeardownBlock { Current.isForegroundApp = previousIsForegroundApp }
        let date = Date()
        Current.isForegroundApp = { false }
        Current.focusStatus.pushes.value = FocusStatusObservation(isFocused: true, date: date)

        Current.isForegroundApp = { true }
        Current.focusStatus.pushes.value = FocusStatusObservation(isFocused: true, date: date.addingTimeInterval(1))

        await fulfillment(of: [signalExpectation], timeout: 10)
        withExtendedLifetime(signaler) {}
    }

    /// A Focus Filter run must signal the sensor: its own explicit update can fail, and it is the
    /// only signal for a Focus whose status iOS doesn't report.
    @MainActor
    func testSignalerFiresOnFilterRun() async throws {
        setUpIOS(liveIsFocused: true)
        _ = Current.sensors.sensors(reason: .registration, server: ServerFixture.standard)

        let observationExpectation = expectation(description: "Observation")
        let signalExpectation = expectation(description: "Signal")
        let signaler = FocusSensorUpdateSignaler(signal: {
            signalExpectation.fulfill()
        })

        signaler.notifyObservation = {
            observationExpectation.fulfill()
        }

        await fulfillment(of: [observationExpectation], timeout: 10)

        Current.focusFilter.runs.value = FocusFilterState(name: "Personal", date: Date())

        await fulfillment(of: [signalExpectation], timeout: 10)
        withExtendedLifetime(signaler) {}
    }
}
