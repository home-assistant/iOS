import PromiseKit
import Shared
import UIKit

/// Minimal scene delegate whose sole responsibility is forwarding Home-screen quick actions
/// (app-icon shortcuts / `UIApplicationShortcutItem`) into `IncomingURLHandler.handle(shortcutItem:)`.
///
/// Under the SwiftUI `App` lifecycle the app-delegate-level `application(_:performActionFor:)`
/// is never called, so quick actions must be received at the scene level. This delegate is attached
/// to the `"WebView"` scene configuration in `AppDelegate.application(_:configurationForConnecting:options:)`.
///
/// It deliberately does **not** create or own a `UIWindow` — SwiftUI's `WindowGroup` (see `HAApp`)
/// keeps hosting `ContainerView`. Adding this delegate must not change scene/window setup, only route
/// the shortcut item, mirroring how `HAApp` re-wires `.onOpenURL` via the same `appCoordinator` bridge.
final class QuickActionWindowSceneDelegate: UIResponder, UIWindowSceneDelegate {
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        // Cold launch: the app was launched by tapping a quick action.
        // This getter does not exist on macOS 10.15, so check that it responds before accessing it.
        guard let windowScene = scene as? UIWindowScene,
              connectionOptions.responds(to: #selector(getter: UIScene.ConnectionOptions.shortcutItem)),
              let shortcutItem = connectionOptions.shortcutItem else { return }
        self.windowScene(windowScene, performActionFor: shortcutItem, completionHandler: { _ in })
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        // Warm launch: the app was already running/backgrounded when the quick action was tapped.
        // Wait for the coordinator (web view ready) just like `HAApp.handleIncoming(url:)`.
        Current.sceneManager.appCoordinator.done { coordinator in
            IncomingURLHandler(coordinator: coordinator).handle(shortcutItem: shortcutItem)
                .done {
                    completionHandler(true)
                }.catch { _ in
                    completionHandler(false)
                }
        }
    }
}
