import CoreSpotlight
import PromiseKit
import Shared
import SwiftUI
import UIKit

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
