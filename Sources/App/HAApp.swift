import CoreSpotlight
import PromiseKit
import Shared
import SwiftUI

#if os(macOS)
@main
struct HAApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        // Registered while the scene graph is built rather than when a window appears: the app can be
        // running with no window at all, and the menu bar item still has to be able to open one.
        let _ = MacWindowOpener.shared.register(openWindow)

        // Main Onboarding + Home Assistant Frontend
        WindowGroup(id: SceneActivity.webView.activityIdentifier) {
            ConditionalContainerView()
                .toastOverlay()
                .onOpenURL { handleIncoming(url: $0) }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { handleIncoming(userActivity: $0) }
                .onContinueUserActivity(CSSearchableItemActionType) { handleIncoming(userActivity: $0) }
                // A link opens in the window that is already there instead of in a new one.
                .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
                .toggleStyle(.haStyle)
                .background(MacBrowserModeWindowGuard())
                .frame(
                    minWidth: SceneActivity.webView.minimumWindowSize.width,
                    minHeight: SceneActivity.webView.minimumWindowSize.height
                )
        }
        .defaultSize(SceneActivity.webView.initialWindowSize)
        .commands {
            MainWindowGroupCommands()
            AppMenuBarCommands()
            MacWebViewCommands()
        }

        Window(L10n.Settings.NavigationBar.title, id: SceneActivity.settings.activityIdentifier) {
            SettingsView()
                .injectingViewControllerProvider()
        }
        .defaultSize(SceneActivity.settings.initialWindowSize)

        Window(L10n.About.title, id: SceneActivity.about.activityIdentifier) {
            NavigationStack {
                AboutView()
            }
            .injectingViewControllerProvider()
        }
        .defaultSize(SceneActivity.about.initialWindowSize)

        Window(L10n.Assist.ModernUi.Header.title, id: SceneActivity.assist.activityIdentifier) {
            AssistWindowView()
                .injectingViewControllerProvider()
        }
        .defaultSize(SceneActivity.assist.initialWindowSize)

        WindowGroup(id: SceneActivity.onboarding.activityIdentifier) {
            OnboardingNavigationView(onboardingStyle: .secondary)
                .injectingViewControllerProvider()
                .frame(
                    minWidth: SceneActivity.onboarding.minimumWindowSize.width,
                    minHeight: SceneActivity.onboarding.minimumWindowSize.height
                )
        }
        .defaultSize(SceneActivity.onboarding.initialWindowSize)
    }

    /// Routes deep links (`homeassistant://…`) and universal web links into `IncomingURLHandler` once the
    /// app coordinator is available.
    @MainActor
    private func handleIncoming(url: URL) {
        // Synchronously, before waiting on the coordinator: the link names where to land, so
        // location-based home switching must not fire for the activation it is opening.
        LocationBasedServerSwitcher.shared.deepLinkWillOpen()
        Current.sceneManager.appCoordinator.done { IncomingURLHandler(coordinator: $0).handle(url: url) }
    }

    @MainActor
    private func handleIncoming(userActivity: NSUserActivity) {
        LocationBasedServerSwitcher.shared.deepLinkWillOpen()
        Current.sceneManager.appCoordinator.done {
            IncomingURLHandler(coordinator: $0).handle(userActivity: userActivity)
        }
    }
}
#else
@main
struct HAApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Main Onboarding + Home Assistant Frontend
        WindowGroup {
            ConditionalContainerView()
                .toastOverlay()
                .onOpenURL { handleIncoming(url: $0) }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { handleIncoming(userActivity: $0) }
                .onContinueUserActivity(CSSearchableItemActionType) { handleIncoming(userActivity: $0) }
                // SwiftUI copy of the launch screen; hides the system-splash → first-screen hand-off by
                // morphing the splash logo into the first screen's logo before fading out.
                .overlay { LaunchSplashOverlayView(state: .shared) }
                .toggleStyle(.haStyle)
        }
        .handlesExternalEvents(matching: [SceneActivity.webView.activityIdentifier])
        .commands {
            MainWindowGroupCommands()
            AppMenuBarCommands()
        }

        // Mac Settings
        WindowGroup {
            SettingsView()
                .toggleStyle(.haStyle)
        }
        .handlesExternalEvents(matching: [SceneActivity.settings.activityIdentifier])

        // Mac About
        WindowGroup {
            NavigationView {
                AboutView()
            }
            .navigationViewStyle(.stack)
            .toggleStyle(.haStyle)
        }
        .handlesExternalEvents(matching: [SceneActivity.about.activityIdentifier])

        // Mac Assist
        WindowGroup {
            AssistWindowView()
                .toggleStyle(.haStyle)
        }
        .handlesExternalEvents(matching: [SceneActivity.assist.activityIdentifier])

        // Mac Onboarding
        WindowGroup {
            OnboardingNavigationView(onboardingStyle: .secondary)
                .toggleStyle(.haStyle)
        }
        .handlesExternalEvents(matching: [SceneActivity.onboarding.activityIdentifier])
    }

    /// Routes deep links (`homeassistant://…`) and universal / NFC web links into `IncomingURLHandler` once
    /// the app coordinator is available — replacing the deleted `WebViewSceneDelegate`'s
    /// `scene(_:openURLContexts:)` / `scene(_:continue:)` under the SwiftUI lifecycle.
    @MainActor
    private func handleIncoming(url: URL) {
        // Synchronously, before waiting on the coordinator: the link names where to land, so
        // location-based home switching must not fire for the activation it is opening.
        LocationBasedServerSwitcher.shared.deepLinkWillOpen()
        Current.sceneManager.appCoordinator.done { IncomingURLHandler(coordinator: $0).handle(url: url) }
    }

    @MainActor
    private func handleIncoming(userActivity: NSUserActivity) {
        LocationBasedServerSwitcher.shared.deepLinkWillOpen()
        Current.sceneManager.appCoordinator.done {
            IncomingURLHandler(coordinator: $0).handle(userActivity: userActivity)
        }
    }
}
#endif
