import PromiseKit
import Shared
import SwiftUI
import UIKit

@main
struct HAApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContainerView()
                .onOpenURL { handleIncoming(url: $0) }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { handleIncoming(userActivity: $0) }
        }

        WindowGroup {
            SettingsView()
        }
        .handlesExternalEvents(matching: [SceneActivity.settings.activityIdentifier])

        WindowGroup {
            NavigationView {
                AboutView()
            }
            .navigationViewStyle(.stack)
        }
        .handlesExternalEvents(matching: [SceneActivity.about.activityIdentifier])

        WindowGroup {
            AssistWindowView()
        }
        .handlesExternalEvents(matching: [SceneActivity.assist.activityIdentifier])

        WindowGroup {
            OnboardingHostingView(onboardingStyle: .secondary)
        }
        .handlesExternalEvents(matching: [SceneActivity.onboarding.activityIdentifier])
    }

    /// Routes deep links (`homeassistant://…`) and universal / NFC web links into `IncomingURLHandler` once
    /// the app coordinator is available — replacing the deleted `WebViewSceneDelegate`'s
    /// `scene(_:openURLContexts:)` / `scene(_:continue:)` under the SwiftUI lifecycle.
    private func handleIncoming(url: URL) {
        Current.sceneManager.appCoordinator.done { IncomingURLHandler(coordinator: $0).handle(url: url) }
    }

    private func handleIncoming(userActivity: NSUserActivity) {
        Current.sceneManager.appCoordinator.done {
            IncomingURLHandler(coordinator: $0).handle(userActivity: userActivity)
        }
    }
}
