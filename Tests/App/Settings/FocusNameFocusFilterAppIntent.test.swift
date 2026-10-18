@testable import HomeAssistant
@testable import Shared
import Testing

// The Focus Filter is the only thing that ever tells the app *which* Focus is running, and iOS runs
// it in a process it may have just launched in the background. What matters is that the name it was
// given is stored before any of the reporting that can fail — a Focus whose report never reaches a
// server is still a Focus the sensors should name.
// Serialized because `withNoServers` swaps the process-wide servers, APIs, focus filter and
// connectivity, and suspends while `perform()` runs — run in parallel, one test would see or
// restore another's fakes.
@Suite(.serialized)
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
}
