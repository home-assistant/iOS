import Combine
import Foundation
@testable import HomeAssistant
import Shared
import Testing

/// Flips the App Labs tab bar flag in the store the way the App Labs screen does and checks what follows it.
@MainActor
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

    @Test("The shared state and the hamburger gesture follow the App Labs flag")
    func stateFollowsTheFlag() async throws {
        let previousIsTestFlight = Current.isTestFlight
        Current.isTestFlight = true
        defer {
            Current.appLabs.setEnabled(false, featureId: AppLabsFeature.iosNativeTabBar.rawValue)
            Current.isTestFlight = previousIsTestFlight
        }
        try await setTabBar(enabled: false)

        let state = NativeTabBarState()
        #expect(!state.isEnabled)
        #expect(HAGestureAction.showSidebar.isAvailable)
        #expect(HAGestureAction.backPage.isAvailable)
        #expect(
            GesturesSetupView.gestureActionsPickerContent.sections
                .flatMap(\.items).contains { $0.id == HAGestureAction.showSidebar.rawValue }
        )
        #expect(WebViewExternalBusMessage.configResult["hasSidebar"] as? Bool == false)

        let sidebarGesture = MockWebViewController()
        let handler = WebViewGestureHandler()
        handler.webView = sidebarGesture
        handler.handleGestureAction(.showSidebar)
        #expect(
            (sidebarGesture.webViewExternalMessageHandler as? MockWebViewExternalMessageHandler)?
                .sendExternalBusCalled == true
        )

        try await setTabBar(enabled: true)
        for _ in 0 ..< 100 where !state.isEnabled {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(state.isEnabled)
        #expect(!HAGestureAction.showSidebar.isAvailable)
        #expect(
            !GesturesSetupView.gestureActionsPickerContent.sections
                .flatMap(\.items).contains { $0.id == HAGestureAction.showSidebar.rawValue }
        )
        #expect(WebViewExternalBusMessage.configResult["hasSidebar"] as? Bool == true)

        let ignoredGesture = MockWebViewController()
        handler.webView = ignoredGesture
        handler.handleGestureAction(.showSidebar)
        #expect(
            (ignoredGesture.webViewExternalMessageHandler as? MockWebViewExternalMessageHandler)?
                .sendExternalBusCalled == false
        )

        var moreRequests = 0
        let cancellable = state.moreRequests.sink { moreRequests += 1 }
        state.requestMore()
        #expect(moreRequests == 1)
        cancellable.cancel()
    }
}
