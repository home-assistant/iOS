@testable import HomeAssistant
import SwiftUI
import Testing

struct GesturesSetupViewTests {
    @MainActor
    @Test func testUI() async throws {
        assertLightDarkSnapshots(of: NavigationView { GesturesSetupView() }, drawHierarchyInKeyWindow: true)
    }
}
