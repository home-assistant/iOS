@testable import HomeAssistant
import SharedTesting
import SwiftUI
import Testing

struct AssistSettingsViewSnapshotTests {
    @available(iOS 18, *)
    @MainActor @Test func settings() {
        assertLightDarkSnapshots(
            of: AssistSettingsView(),
            drawHierarchyInKeyWindow: true
        )
    }
}
