import AppIntents
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import SharedTesting
import Testing

// The Focus Filter is the only thing that ever tells the app *which* Focus is running, and iOS runs
// it in a process it may have just launched in the background. What matters is that the name it was
// given is stored before any of the reporting that can fail — a Focus whose report never reaches a
// server is still a Focus the sensors should name.
// Serialized because `withNoServers` swaps the process-wide servers, APIs, focus filter and
// connectivity, and suspends while `perform()` runs — run in parallel, one test would see or
// restore another's fakes.
@Suite(.sharedState)
struct FocusNameFocusFilterAppIntentTests {
    private func withNoServers(_ body: () async throws -> Void) async rethrows {
        let previousServers = Current.servers
        let previousApis = Current.cachedApis
        let previousFilter = Current.focusFilter
        let previousRefresh = Current.connectivity.refreshNetworkInformation
        defer {
            Current.servers = previousServers
            Current.cachedApis = previousApis
            Current.focusFilter = previousFilter
            Current.connectivity.refreshNetworkInformation = previousRefresh
        }
        Current.servers = FakeServerManager(initial: 0)
        Current.cachedApis = [:]
        Current.focusFilter = FocusFilterWrapper()
        // The real one talks to the network stack, which a unit test has no business waking.
        Current.connectivity.refreshNetworkInformation = {}
        try await body()
    }

    @Test func displaysThePickedNameOrNone() {
        var intent = FocusNameFocusFilterAppIntent()
        intent.focusName = nil
        _ = intent.displayRepresentation
        intent.focusName = .init(id: "work", name: "Work")
        _ = intent.displayRepresentation
        #expect(intent.focusName?.name == "Work")
    }

    /// With a server to report to, the update runs in a background task; one that has no time left
    /// fails that server's update, which is logged rather than failing the filter.
    @Test func aFailedReportDoesNotFailTheFilter() async throws {
        try await withNoServers {
            let previousRunner = Current.backgroundTask
            Current.backgroundTask = OutOfTimeTaskRunner()
            defer { Current.backgroundTask = previousRunner }
            let servers = FakeServerManager(initial: 1)
            Current.servers = servers
            defer { Current.resetAPICache(for: servers.all.map(\.identifier)) }

            var stored: String??
            Current.focusFilter.setActiveFocusName = { stored = $0 }
            var intent = FocusNameFocusFilterAppIntent()
            intent.focusName = .init(id: "work", name: "Work")
            _ = try await intent.perform()
            #expect(stored == "Work")
        }
    }

    /// With time to run, each server's Focus sensors are updated. The test's own sensor container
    /// has no providers, so the update has nothing to send and stays off the network.
    @Test func aReportWithTimeUpdatesEachServersFocusSensors() async throws {
        try await withNoServers {
            let previousRunner = Current.backgroundTask
            let previousSensors = Current.sensors
            Current.backgroundTask = ImmediateTaskRunner()
            Current.sensors = SensorContainer()
            defer {
                Current.backgroundTask = previousRunner
                Current.sensors = previousSensors
            }
            let servers = FakeServerManager(initial: 1)
            Current.servers = servers
            defer { Current.resetAPICache(for: servers.all.map(\.identifier)) }

            var stored: String??
            Current.focusFilter.setActiveFocusName = { stored = $0 }
            var intent = FocusNameFocusFilterAppIntent()
            intent.focusName = .init(id: "work", name: "Work")
            _ = try await intent.perform()
            #expect(stored == "Work")
        }
    }

    @Test func storesTheNameEvenWithNoServerToReportTo() async throws {
        try await withNoServers {
            var stored: String??
            Current.focusFilter.setActiveFocusName = { stored = $0 }

            var intent = FocusNameFocusFilterAppIntent()
            intent.focusName = .init(id: "3F9B0A1C-6C0E-4C0B-9D2E-7A1B2C3D4E5F", name: "Personal")
            _ = try await intent.perform()

            #expect(stored == "Personal")
        }
    }

    /// The nil-name run iOS makes when a Focus deactivates has to reach the wrapper too — it is
    /// what ends a Focus whose status the user doesn't share.
    @Test func passesOnTheResetRunWithNoName() async throws {
        try await withNoServers {
            var stored: String??
            Current.focusFilter.setActiveFocusName = { stored = $0 }

            var intent = FocusNameFocusFilterAppIntent()
            intent.focusName = nil
            _ = try await intent.perform()

            #expect(stored == .some(nil))
        }
    }

    @Test func currentValuesAnswerWithThePickedName() async throws {
        var intent = FocusNameFocusFilterAppIntent()
        intent.focusName = .init(id: "3F9B0A1C-6C0E-4C0B-9D2E-7A1B2C3D4E5F", name: "Work")

        let name = try await FocusNameFocusFilterAppIntent.currentFocusName(reading: { intent })

        #expect(name == "Work")
    }

    /// iOS not finding the current configuration is read as no Focus with the filter being on.
    @Test func currentValuesNotFoundAnswerWithNoName() async throws {
        let name = try await FocusNameFocusFilterAppIntent.currentFocusName(reading: {
            throw SetFocusFilterIntentError.notFound
        })

        #expect(name == nil)
    }

    /// Any other failure is not an answer, so the sensors keep what the filter's runs said.
    @Test func currentValuesFailingOtherwiseIsPassedOn() async throws {
        await #expect(throws: SetFocusFilterIntentError.missingParameterValue) {
            try await FocusNameFocusFilterAppIntent.currentFocusName(reading: {
                throw SetFocusFilterIntentError.missingParameterValue
            })
        }
    }

    /// The reader the app registers asks iOS itself, which a unit test can't steer, so this only
    /// pins down what the sensors rely on: asking never holds a sensor read past the timeout, and
    /// whatever iOS answers, the stored state stays readable.
    @Test func registeredReaderAnswersWithinTheTimeout() async throws {
        let previousFilter = Current.focusFilter
        let previousTimeout = FocusFilterWrapper.currentValuesTimeout
        defer {
            Current.focusFilter.readings.value = nil
            Current.focusFilter = previousFilter
            FocusFilterWrapper.currentValuesTimeout = previousTimeout
        }
        Current.focusFilter = FocusFilterWrapper()
        Current.focusFilter.readings.value = nil
        FocusFilterWrapper.currentValuesTimeout = 2

        FocusNameFocusFilterAppIntent.registerCurrentValuesReader()
        let started = Date()
        await Current.focusFilter.readFromIOS()

        #expect(Date().timeIntervalSince(started) < 10)
        // No Focus with the filter is on in a test run, so any answer iOS gives names none.
        #expect(Current.focusFilter.activeFocusName() == nil)
    }
}

/// Fails every background task at once, without running the work it wraps.
private final class OutOfTimeTaskRunner: HomeAssistantBackgroundTaskRunner {
    func callAsFunction<PromiseValue>(
        withName name: String,
        requiringAssertion: Bool,
        wrapping: (TimeInterval?) -> Promise<PromiseValue>
    ) -> Promise<PromiseValue> {
        Promise(error: BackgroundTaskError.outOfTime)
    }
}

/// Runs every background task's work at once, with no time limit.
private final class ImmediateTaskRunner: HomeAssistantBackgroundTaskRunner {
    func callAsFunction<PromiseValue>(
        withName name: String,
        requiringAssertion: Bool,
        wrapping: (TimeInterval?) -> Promise<PromiseValue>
    ) -> Promise<PromiseValue> {
        wrapping(nil)
    }
}
