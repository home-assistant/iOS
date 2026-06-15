import PromiseKit
import Shared
import SwiftUI
import UIKit

/// SwiftUI application entry point.
///
/// A deliberate **hybrid** lifecycle: the SwiftUI `App` is `@main`, but the full `AppDelegate` is retained
/// via `@UIApplicationDelegateAdaptor` because CarPlay, remote-notification registration, background work,
/// Siri intents and Mac Catalyst menus have no SwiftUI equivalent at our iOS 15 deployment target and must
/// stay on the UIKit delegates.
///
/// **Window ownership:** SwiftUI `WindowGroup`s host the primary window (`ContainerView`: onboarding vs.
/// web frontend) plus Settings, About and Assist. Each scene is matched to its group with
/// `handlesExternalEvents` against the `SceneActivity` that `SceneManager.activateAnyScene` activates (via
/// `NSUserActivity.targetContentIdentifier`). `WindowGroup(id:)`/`openWindow` aren't used because they're
/// iOS 16+; `handlesExternalEvents` is iOS 14+ and works with the existing `requestSceneSessionActivation`
/// opening path. `AppDelegate`'s `configurationForConnecting` returns delegate-less configurations for these
/// scenes so SwiftUI (not a `UIWindowSceneDelegate`) hosts them; Onboarding (Catalyst "add server") and
/// CarPlay keep their `Info.plist`-bound delegates.
@main
struct HAApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContainerView()
                .onOpenURL { handleIncoming(url: $0) }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { handleIncoming(userActivity: $0) }
        }
        .handlesExternalEvents(matching: [SceneActivity.webView.activityIdentifier])

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
