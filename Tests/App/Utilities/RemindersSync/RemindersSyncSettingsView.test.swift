@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing

struct RemindersSyncSettingsViewTests {
    /// Tall enough that every section, including the completed-items toggle at the bottom, is in
    /// the frame. Reminders access is reported as granted and the settings are the defaults, so the
    /// screen doesn't depend on the test host's EventKit permission or saved defaults.
    @MainActor
    @Test func testSettingsView() async throws {
        let viewModel = RemindersSyncSettingsViewModel(
            authorizationState: { .authorized },
            settings: { RemindersSyncSettings() }
        )
        assertLightDarkSnapshots(
            of: NavigationView { RemindersSyncSettingsView(viewModel: viewModel) },
            layout: .fixed(width: 393, height: 1500)
        )
    }

    /// The new toggle is reachable from settings search.
    @Test func searchIndexesTheCompletedItemsToggle() {
        let titles = RemindersSyncSettingsView.settingsSearchEntries.map(\.title)
        #expect(titles.contains(L10n.RemindersSync.Settings.Completed.title))
    }
}
