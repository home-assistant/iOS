@testable import HomeAssistant
import Shared
import Testing

struct AppLabsViewTests {
    @MainActor
    @Test func testUI() async throws {
        assertLightDarkSnapshots(of: AppLabsView())
    }

    @Test func appLabsIsAvailableOnEveryBuild() {
        let previousIsTestFlight = Current.isTestFlight
        defer { Current.isTestFlight = previousIsTestFlight }

        Current.isTestFlight = false
        #expect(SettingsItem.appLabs.isVisible)

        Current.isTestFlight = true
        #expect(SettingsItem.appLabs.isVisible)
    }
}
