@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing
import UIKit
import UserNotifications

// Serialized: the tests swap `Current.isCatalyst`, which concurrent tests would race on.
@Suite(.sharedState)
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

    @Test func settingsSearchIndexesTapActionsRow() {
        let titles = NotificationSettingsView.settingsSearchEntries.map(\.title)
        #expect(titles.contains(L10n.SettingsDetails.Notifications.TapActions.title))
    }

    /// The row is the only way into the feature, so its switch has to reach the store the presenter
    /// reads.
    @MainActor
    @Test func tapActionsToggleWritesThroughToSettings() {
        let previous = Current.settingsStore.notificationTapActionsEnabled
        defer { Current.settingsStore.notificationTapActionsEnabled = previous }

        Current.settingsStore.notificationTapActionsEnabled = false
        let viewModel = NotificationSettingsViewModel()
        #expect(viewModel.tapActionsEnabled == false)

        viewModel.tapActionsEnabled = true

        #expect(Current.settingsStore.notificationTapActionsEnabled)
    }

    /// Every authorization status reads as enabled, disabled or "needs request".
    @MainActor
    @Test func permissionStatusesDescribeThemselves() {
        let enabled = L10n.SettingsDetails.Notifications.Permission.enabled
        let disabled = L10n.SettingsDetails.Notifications.Permission.disabled
        #expect(NotificationSettingsViewModel.permissionText(for: .authorized) == enabled)
        #expect(NotificationSettingsViewModel.permissionText(for: .provisional) == enabled)
        #expect(NotificationSettingsViewModel.permissionText(for: .ephemeral) == enabled)
        #expect(NotificationSettingsViewModel.permissionText(for: .denied) == disabled)
        #expect(
            NotificationSettingsViewModel.permissionText(for: .notDetermined) ==
                L10n.SettingsDetails.Notifications.Permission.needsRequest
        )
        #expect(NotificationSettingsViewModel.permissionText(for: UNAuthorizationStatus(rawValue: 99)!) == disabled)
    }

    /// The badge and force-close switches write through to the settings store. Turning the force-close
    /// warning on would ask for notification permission, so only switching it off is exercised.
    @MainActor
    @Test func switchesWriteThroughToSettings() {
        let previousClear = Current.settingsStore.clearBadgeAutomatically
        let previousForceClose = Current.settingsStore.forceCloseWarningEnabled
        defer {
            Current.settingsStore.clearBadgeAutomatically = previousClear
            Current.settingsStore.forceCloseWarningEnabled = previousForceClose
        }

        let viewModel = NotificationSettingsViewModel()
        viewModel.clearBadgeAutomatically = !previousClear
        #expect(Current.settingsStore.clearBadgeAutomatically == !previousClear)
        viewModel.forceCloseWarningEnabled = false
        #expect(!Current.settingsStore.forceCloseWarningEnabled)
    }

    /// Presented from a notification, the screen offers Done; clearing the badge resets the count.
    @MainActor
    @Test func doneAndClearingTheBadge() async {
        let previousBadge = UIApplication.shared.applicationIconBadgeNumber
        defer { UIApplication.shared.applicationIconBadgeNumber = previousBadge }
        UIApplication.shared.applicationIconBadgeNumber = 3

        let driver = await SwiftUIScreenDriver.show(NotificationSettingsView(showsDoneButton: true))
        defer { driver.close() }
        let pressed = await driver.tapBarButton(titled: L10n.doneLabel)
        #expect(pressed)

        // Header, overview, history/snooze/sounds, tap actions, then the badge section.
        await driver.tapRow(IndexPath(item: 0, section: 4))
        #expect(UIApplication.shared.applicationIconBadgeNumber == 0)
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
