import PromiseKit
import Shared
import UIKit

/// Scene delegate for the primary `"WebView"` scene under the SwiftUI `App` lifecycle. It covers two
/// behaviours the SwiftUI lifecycle cannot express on its own:
///
/// 1. Forwarding Home-screen quick actions (app-icon shortcuts / `UIApplicationShortcutItem`) into
///    `IncomingURLHandler.handle(shortcutItem:)`. The app-delegate-level `application(_:performActionFor:)`
///    is never called under the SwiftUI lifecycle, so quick actions must be received at the scene level.
/// 2. Honouring the Mac "Open Home Assistant UI in browser" setting (`macNativeFeaturesOnly`): on a plain
///    app-icon launch it opens Home Assistant in the user's default browser and destroys the otherwise-empty
///    webview window.
/// 3. Persisting and restoring the Mac window size and position across launches via `WindowScenesManager`.
///    The SwiftUI `WindowGroup` lifecycle does not restore the previous window geometry on its own, so the
///    scene lifecycle is forwarded to `WindowScenesManager` (which saves the latest frame and re-applies it).
///
/// All three behaviours previously lived in the now-removed `WebViewSceneDelegate`. This delegate is attached to
/// the `"WebView"` scene configuration in `AppDelegate.application(_:configurationForConnecting:options:)`.
/// In the normal (non-browser) case it does not create or own a `UIWindow` — SwiftUI's `WindowGroup`
/// (see `HAApp`) keeps hosting `ContainerView`.
final class QuickActionWindowSceneDelegate: UIResponder, UIWindowSceneDelegate {
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        // Cold launch via a quick action: the app was launched by tapping an app-icon shortcut.
        // This getter does not exist on macOS 10.15, so check that it responds before accessing it.
        if connectionOptions.responds(to: #selector(getter: UIScene.ConnectionOptions.shortcutItem)),
           let shortcutItem = connectionOptions.shortcutItem {
            self.windowScene(windowScene, performActionFor: shortcutItem, completionHandler: { _ in })
            return
        }

        // "Open Home Assistant UI in browser" (Mac): when the app is opened by tapping its icon, open
        // Home Assistant in the default browser and destroy the empty webview window so none is left behind.
        if Current.isCatalyst, Current.settingsStore.macNativeFeaturesOnly,
           let url = Current.servers.all.first?.info.connection.activeURL() {
            URLOpener.shared.open(url, options: [:], completionHandler: nil)
            UIApplication.shared.requestSceneSessionDestruction(session, options: nil, errorHandler: nil)
        }
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

    func sceneDidBecomeActive(_ scene: UIScene) {
        guard let windowScene = scene as? UIWindowScene else { return }
        WindowScenesManager.shared.sceneDidBecomeActive(windowScene)
    }

    func sceneWillResignActive(_ scene: UIScene) {
        WindowScenesManager.shared.sceneWillResignActive(scene)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        WindowScenesManager.shared.didDiscardScene(scene)
    }
}
