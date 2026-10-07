@testable import HomeAssistant
import SwiftUI
import Testing

struct ServerSwitchingHowItWorksViewTests {
    @MainActor
    @Test func howItWorksScreen() async throws {
        assertLightDarkSnapshots(
            of: NavigationView { ServerSwitchingHowItWorksView() },
            drawHierarchyInKeyWindow: true
        )
    }
}
