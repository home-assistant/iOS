@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SnapshotTesting
import SwiftUI
import Testing
import UIKit

struct RemindersSyncSettingsViewTests {
    /// Tall enough that every section, including the completed-items toggle at the bottom, is in
    /// the frame. Reminders access is reported as granted and the settings are the defaults, so the
    /// screen doesn't depend on the test host's EventKit permission or saved defaults.
    ///
    /// On a mismatch the rendered image is attached to the result bundle, so a reference can be
    /// taken from the machine that ran the test.
    @MainActor
    @Test func testSettingsView() async throws {
        let viewModel = RemindersSyncSettingsViewModel(
            authorizationState: { .authorized },
            settings: { RemindersSyncSettings() }
        )
        for style in [UIUserInterfaceStyle.light, UIUserInterfaceStyle.dark] {
            let name = style == .light ? "light" : "dark"
            let failure = verifySnapshot(
                of: NavigationView { RemindersSyncSettingsView(viewModel: viewModel) },
                as: .image(
                    drawHierarchyInKeyWindow: true,
                    precision: defaultSnapshotPrecision,
                    perceptualPrecision: defaultSnapshotPrecision,
                    layout: .fixed(width: 390, height: 1500),
                    traits: .init(userInterfaceStyle: style)
                ),
                named: name
            )
            guard let failure else { continue }
            if let start = failure.range(of: "@+\n\"file://"),
               let end = failure[start.upperBound...].firstIndex(of: "\""),
               let image = UIImage(contentsOfFile: String(failure[start.upperBound ..< end])) {
                Attachment.record(image, named: "rendered-\(name)")
            }
            Issue.record(Comment(rawValue: failure))
        }
    }

    /// The new toggle is reachable from settings search.
    @Test func searchIndexesTheCompletedItemsToggle() {
        let titles = RemindersSyncSettingsView.settingsSearchEntries.map(\.title)
        #expect(titles.contains(L10n.RemindersSync.Settings.Completed.title))
    }
}
