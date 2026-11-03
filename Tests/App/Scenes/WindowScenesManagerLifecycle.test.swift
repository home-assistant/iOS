import Foundation
@testable import HomeAssistant
import SharedTesting
import Testing
import UIKit

/// The window geometry bookkeeping across a scene's life: a connecting scene is sized once, an active
/// scene is observed until it resigns or is discarded, a saved main-window frame is restored (cascaded
/// when several main windows are open) and other windows reopen exactly where they were. The main
/// scene's delegate forwards its lifecycle to the shared manager.
///
/// `.sharedState`: saved frames live in the app group preferences, and the shared manager is driven
/// with the host app's own scene.
@Suite(.sharedState)
@MainActor
struct WindowScenesManagerLifecycleTests {
    private func preservingFrames(_ body: () throws -> Void) rethrows {
        let saved = SceneActivity.allCases.map { prefs.data(forKey: ScenesWindowSizeConfig.key(for: $0)) }
        defer {
            for (activity, data) in zip(SceneActivity.allCases, saved) {
                prefs.set(data, forKey: ScenesWindowSizeConfig.key(for: activity))
            }
        }
        try body()
    }

    @Test func anActiveSceneIsObservedUntilItResigns() throws {
        let scene = try #require(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let manager = WindowScenesManager()

        manager.sceneWillConnect(scene, activity: .assist)
        manager.sceneWillConnect(scene, activity: .assist)
        manager.sceneDidBecomeActive(scene, activity: .webView)
        manager.sceneDidBecomeActive(scene, activity: .webView)
        #expect(manager.windowSizeObservers.count == 1)

        manager.sceneWillResignActive(scene)
        #expect(manager.windowSizeObservers.isEmpty)

        manager.sceneDidBecomeActive(scene, activity: .webView)
        manager.didDiscardScene(scene)
        #expect(manager.windowSizeObservers.isEmpty)
    }

    @Test func savedFramesAreRestoredPerWindowKind() {
        preservingFrames {
            let manager = WindowScenesManager()
            let screen = CGSize(width: 1440, height: 900)
            let frame = CGRect(x: 100, y: 100, width: 800, height: 600)

            ScenesWindowSizeConfig.setLatestSystemFrame(frame, for: .webView)
            let main = manager.systemFrame(for: .webView, screenSize: screen)
            // However many main windows the host has open, the restored frame is the saved one or its cascade.
            #expect(main == frame || main == frame.offsetBy(dx: 29, dy: 29))

            ScenesWindowSizeConfig.setLatestSystemFrame(frame, for: .assist)
            #expect(manager.systemFrame(for: .assist, screenSize: screen) == frame)

            // A saved frame larger than the screen is ignored in favour of the default.
            ScenesWindowSizeConfig.setLatestSystemFrame(CGRect(x: 0, y: 0, width: 4000, height: 3000), for: .assist)
            #expect(manager.systemFrame(for: .assist, screenSize: screen)?.size == CGSize(width: 400, height: 600))
            ScenesWindowSizeConfig.setLatestSystemFrame(nil, for: .settings)
            #expect(manager.systemFrame(for: .settings, screenSize: screen) == nil)
        }
    }

    @Test func theMainSceneDelegateForwardsItsLifecycle() throws {
        let scene = try #require(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let delegate = QuickActionWindowSceneDelegate()
        let before = WindowScenesManager.shared.windowSizeObservers.contains { $0.observedScene == scene }

        delegate.sceneDidBecomeActive(scene)
        #expect(WindowScenesManager.shared.windowSizeObservers.contains { $0.observedScene == scene })
        delegate.sceneWillResignActive(scene)
        #expect(!WindowScenesManager.shared.windowSizeObservers.contains { $0.observedScene == scene })
        delegate.sceneDidDisconnect(scene)

        // Leave the shared manager watching the host scene if it was before.
        if before {
            WindowScenesManager.shared.sceneDidBecomeActive(scene, activity: .webView)
        }
    }
}
