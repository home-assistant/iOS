@testable import HomeAssistant
import Testing
import SwiftUI

struct GesturesSetupViewTests {
    @MainActor
    @Test func testUI() async throws {
        assertLightDarkSnapshots(of: NavigationView {GesturesSetupView()}, drawHierarchyInKeyWindow: true)
    }
}
