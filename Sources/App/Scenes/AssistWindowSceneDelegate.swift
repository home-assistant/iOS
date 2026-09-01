import UIKit

/// Scene delegate for the Mac Assist window. Its only job is remembering the window's size and position
/// across openings: the SwiftUI `WindowGroup` lifecycle does not restore window geometry on its own, so the
/// scene lifecycle is forwarded to `WindowScenesManager` (which saves the latest frame and re-applies it),
/// exactly as `QuickActionWindowSceneDelegate` does for the main window.
///
/// Because the delegate is attached to a single scene configuration (see `SceneActivity.configuration`), it
/// is what identifies the window kind to `WindowScenesManager` — the Assist window therefore never shares a
/// stored frame with the main window, whatever user activity the scene was connected with.
///
/// It never creates or owns a `UIWindow` — SwiftUI keeps hosting the scene's content.
final class AssistWindowSceneDelegate: UIResponder, UIWindowSceneDelegate {
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        WindowScenesManager.shared.sceneWillConnect(windowScene, activity: .assist)
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        guard let windowScene = scene as? UIWindowScene else { return }
        WindowScenesManager.shared.sceneDidBecomeActive(windowScene, activity: .assist)
    }

    func sceneWillResignActive(_ scene: UIScene) {
        WindowScenesManager.shared.sceneWillResignActive(scene)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        WindowScenesManager.shared.didDiscardScene(scene)
    }
}
