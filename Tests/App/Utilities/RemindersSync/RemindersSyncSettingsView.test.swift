@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

struct RemindersSyncSettingsViewTests {
    /// Tall enough that every section, including the completed-items toggle at the bottom, is in
    /// the frame.
    @MainActor
    @Test func testSettingsView() async throws {
        assertLightDarkSnapshots(
            of: NavigationView { RemindersSyncSettingsView() },
            layout: .fixed(width: 393, height: 1500)
        )
    }
}
