@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing
import UIKit

// Serialized: the tests swap `Current.isCatalyst`, which concurrent tests would race on.
@Suite(.serialized)
struct NotificationSettingsViewTests {
    @MainActor
    @Test func rendersWithForceCloseWarningRow() {
        withCatalyst(false) {
            render(NavigationView { NotificationSettingsView() })
        }
    }

    @MainActor
    @Test func rendersWithoutForceCloseWarningRowOnCatalyst() {
        // The manager never fires on Catalyst, so the row — and its search entry — go away with it.
        withCatalyst(true) {
            render(NavigationView { NotificationSettingsView() })
        }
    }

    @Test func settingsSearchIndexesForceCloseWarningRow() {
        withCatalyst(false) {
            let titles = NotificationSettingsView.settingsSearchEntries.map(\.title)
            #expect(titles.contains(L10n.SettingsDetails.Notifications.ForceCloseWarning.title))
        }
    }

    @Test func settingsSearchSkipsForceCloseWarningRowOnCatalyst() {
        withCatalyst(true) {
            let titles = NotificationSettingsView.settingsSearchEntries.map(\.title)
            #expect(!titles.contains(L10n.SettingsDetails.Notifications.ForceCloseWarning.title))
            #expect(titles.contains(L10n.SettingsDetails.Notifications.Sounds.title))
        }
    }

    private func withCatalyst(_ isCatalyst: Bool, _ body: () throws -> Void) rethrows {
        let previous = Current.isCatalyst
        Current.isCatalyst = isCatalyst
        defer { Current.isCatalyst = previous }
        try body()
    }

    /// Lays the view out in a window, which is what makes SwiftUI evaluate the body.
    ///
    /// Deliberately never becomes the key window: the snapshot helpers draw into whatever window is
    /// key, so stealing it here would reach into unrelated tests. The window is torn down again for
    /// the same reason.
    @MainActor
    private func render(_ view: some View) {
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        window.isHidden = true
        window.rootViewController = nil
    }
}
