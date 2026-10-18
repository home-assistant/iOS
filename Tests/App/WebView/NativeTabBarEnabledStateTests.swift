import Combine
import Foundation
import GRDB
@testable import HomeAssistant
@testable import Shared
import Testing

/// Flips the App Labs tab bar flag in the store the way the App Labs screen does and checks what follows it.
@MainActor
@Suite(.serialized)
struct NativeTabBarEnabledStateTests {
    private func setTabBar(enabled: Bool) async throws {
        Current.appLabs.setEnabled(enabled, featureId: AppLabsFeature.iosNativeTabBar.rawValue)
        for _ in 0 ..< 100 where AppLabsFeature.iosNativeTabBar.isEnabled != enabled {
            try await Task.sleep(for: .milliseconds(20))
        }
        try #require(AppLabsFeature.iosNativeTabBar.isEnabled == enabled)
    }

    @Test("The App Labs row describes the tab bar with its own title and description")
    func labsCopy() {
        #expect(AppLabsFeature.iosNativeTabBar.title == L10n.Settings.AppLabs.IosNativeTabBar.title)
        #expect(AppLabsFeature.iosNativeTabBar.footer == L10n.Settings.AppLabs.IosNativeTabBar.summary)
    }

    @Test("The shared state and the frontend sidebar config follow the App Labs flag")
    func stateFollowsTheFlag() async throws {
        let previousIsTestFlight = Current.isTestFlight
        let previousTabBar = Current.appLabs.isEnabled(featureId: AppLabsFeature.iosNativeTabBar.rawValue)
        Current.isTestFlight = true
        defer {
            Current.appLabs.setEnabled(previousTabBar, featureId: AppLabsFeature.iosNativeTabBar.rawValue)
            Current.isTestFlight = previousIsTestFlight
        }
        try await setTabBar(enabled: false)

        let state = NativeTabBarState()
        #expect(!state.isEnabled)
        #expect(WebViewExternalBusMessage.configResult["hasSidebar"] as? Bool == false)

        try await setTabBar(enabled: true)
        for _ in 0 ..< 100 where !state.isEnabled {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(state.isEnabled)
        #expect(WebViewExternalBusMessage.configResult["hasSidebar"] as? Bool == true)

        var moreRequests = 0
        let cancellable = state.moreRequests.sink { moreRequests += 1 }
        state.requestMore()
        #expect(moreRequests == 1)
        cancellable.cancel()
    }

    /// Kiosk mode belongs to the kiosk settings alone. The tab bar gets the layout it needs from
    /// `hasSidebar`, and kiosk mode would also take the dashboard's Add, Search and Edit buttons with it.
    @Test("The tab bar leaves the frontend's kiosk mode to the kiosk settings")
    func tabBarDoesNotEnableKioskMode() async throws {
        let previousIsTestFlight = Current.isTestFlight
        let previousKiosk = Current.kiosk
        let previousTabBar = Current.appLabs.isEnabled(featureId: AppLabsFeature.iosNativeTabBar.rawValue)
        Current.isTestFlight = true
        defer {
            Current.kiosk = previousKiosk
            Current.appLabs.setEnabled(previousTabBar, featureId: AppLabsFeature.iosNativeTabBar.rawValue)
            Current.isTestFlight = previousIsTestFlight
        }

        try await setTabBar(enabled: true)

        // The manager reads its settings from whichever database is current when it is built, so it keeps
        // observing this empty one. `Current.database` itself goes straight back: the tests running
        // alongside this one need the real database.
        let previousDatabase = Current.database
        let database = try DatabaseQueue()
        try KioskSettingsTable().createIfNeeded(database: database)
        Current.database = { database }
        let kiosk = KioskModeManager()
        Current.database = previousDatabase
        Current.kiosk = kiosk
        try #require(!Current.kioskSettings.enabled)

        let controller = WebViewController(server: .fake())
        let handler = MockWebViewExternalMessageHandler()
        controller.webViewExternalMessageHandler = handler

        controller.updateFrontendKioskMode()
        #expect(handler.sendExternalBusCommandWithRetryCommand == .kioskModeSet)
        let enable = handler.sendExternalBusCommandWithRetryPayload?["enable"] as? Bool
        #expect(enable == false)
    }

    /// The tab bar keeps the sidebar gesture working: it travels to the frontend, which bounces it back
    /// as `sidebar/show` because the app answered `hasSidebar`, and that opens the More tab.
    @Test("The sidebar gesture still reaches the frontend while the tab bar is on")
    func sidebarGestureStillReachesTheFrontend() async throws {
        let previousIsTestFlight = Current.isTestFlight
        let previousTabBar = Current.appLabs.isEnabled(featureId: AppLabsFeature.iosNativeTabBar.rawValue)
        Current.isTestFlight = true
        defer {
            Current.appLabs.setEnabled(previousTabBar, featureId: AppLabsFeature.iosNativeTabBar.rawValue)
            Current.isTestFlight = previousIsTestFlight
        }
        try await setTabBar(enabled: true)

        #expect(
            GesturesSetupView.gestureActionsPickerContent.sections
                .flatMap(\.items).contains { $0.id == HAGestureAction.showSidebar.rawValue }
        )

        let webView = MockWebViewController()
        let handler = WebViewGestureHandler()
        handler.webView = webView
        handler.handleGestureAction(.showSidebar)
        #expect(
            (webView.webViewExternalMessageHandler as? MockWebViewExternalMessageHandler)?
                .sendExternalBusCalled == true
        )
    }
}
