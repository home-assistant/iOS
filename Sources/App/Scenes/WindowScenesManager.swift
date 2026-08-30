import Foundation
import Shared
import UIKit

final class WindowScenesManager {
    static let shared = WindowScenesManager()
    private(set) var windowSizeObservers: [WindowSizeObserver] = []
    /// macOS re-activates a window many times during its life. Re-applying the stored frame on every
    /// activation would fight the user (and drift the window by the cascade inset), so each scene session
    /// is restored only the first time it becomes active.
    private var sessionsWithRestoredGeometry: Set<String> = []

    /// Sizing a window while it is connecting, before it is on screen, avoids the visible jump of resizing one
    /// the user can already see. The main window is sized on activation instead, since its own delegate may
    /// still destroy the window while connecting ("Open Home Assistant UI in browser").
    func sceneWillConnect(_ scene: UIWindowScene, activity: SceneActivity) {
        guard sessionsWithRestoredGeometry.insert(scene.session.persistentIdentifier).inserted else { return }
        configureSceneSize(scene, for: activity)
    }

    /// `activity` comes from the scene delegate that reported the activation, not from the scene itself: each
    /// window kind has its own delegate, so the window a frame belongs to is never guessed from the user
    /// activity or configuration name the scene happened to connect with.
    func sceneDidBecomeActive(_ scene: UIWindowScene, activity: SceneActivity) {
        if sessionsWithRestoredGeometry.insert(scene.session.persistentIdentifier).inserted {
            configureSceneSize(scene, for: activity)
        }
        startObservingScene(scene, activity: activity)
    }

    func sceneWillResignActive(_ scene: UIScene) {
        stopObservingScene(scene)
    }

    func didDiscardScene(_ scene: UIScene) {
        sessionsWithRestoredGeometry.remove(scene.session.persistentIdentifier)
        stopObservingScene(scene)
    }

    private func startObservingScene(_ scene: UIWindowScene, activity: SceneActivity) {
        guard !windowSizeObservers.contains(where: { $0.observedScene == scene }) else { return }
        let observer = WindowSizeObserver(windowScene: scene, activity: activity)
        windowSizeObservers.append(observer)
    }

    private func stopObservingScene(_ scene: UIScene) {
        windowSizeObservers.first { observer in
            observer.observedScene == scene
        }?.stopObserving()
        windowSizeObservers.removeAll { $0.observedScene == scene }
    }

    private func sceneFrameIsValid(_ sceneFrame: CGRect, screenSize: CGSize) -> Bool {
        sceneFrame.height <= screenSize.height && sceneFrame.width <= screenSize.width
    }

    // Create cascade effect so windows don't overlap
    func adjustedSystemFrame(
        _ systemFrame: CGRect,
        for screenSize: CGSize,
        numberOfConnectedScenes: Int
    ) -> CGRect {
        guard numberOfConnectedScenes > 1 else { return systemFrame }
        var adjustedFrame = systemFrame

        // Inset from the already presented scene
        // 29 is used by default by the system
        adjustedFrame = adjustedFrame.offsetBy(dx: 29, dy: 29)

        // Move to the top if we are out of the screen's bottom
        if adjustedFrame.origin.y + adjustedFrame.height > screenSize.height - 80 {
            adjustedFrame.origin.y = 80
        }

        // Move to left if we are out of the screen's right side
        if adjustedFrame.origin.x + adjustedFrame.width > screenSize.width - 20 {
            adjustedFrame.origin.x = 20
        }

        return adjustedFrame
    }

    private func configureSceneSize(_ scene: UIWindowScene, for activity: SceneActivity) {
        guard #available(macCatalyst 16.0, *) else { return }

        let screenSize = scene.screen.bounds.size
        guard let systemFrame = systemFrame(for: activity, screenSize: screenSize) else { return }

        #if targetEnvironment(macCatalyst)
        Current.Log.info("Sizing \(activity.configurationName) window to \(systemFrame)")
        scene.requestGeometryUpdate(.Mac(systemFrame: systemFrame)) { error in
            Current.Log.info(userInfo: ["Failed to request mac geometry": error.localizedDescription])
        }
        #endif
    }

    /// The frame a window should open at: the one the user last left it at, or the window kind's own default
    /// when it has never been placed. Without a default, macOS opens a new window at the frame of the window
    /// that was already frontmost, which is why the Assist window used to inherit the main window's geometry.
    func systemFrame(for activity: SceneActivity, screenSize: CGSize) -> CGRect? {
        if let savedSystemFrame = ScenesWindowSizeConfig.latestSystemFrame(for: activity),
           savedSystemFrame != .zero,
           sceneFrameIsValid(savedSystemFrame, screenSize: screenSize) {
            return restoredSystemFrame(savedSystemFrame, for: activity, screenSize: screenSize)
        }
        guard let defaultSize = activity.defaultMacWindowSize else { return nil }
        return centeredFrame(for: defaultSize, screenSize: screenSize)
    }

    /// Only the main window can have several instances open at once, so it is the only one that cascades, and
    /// only its own windows count towards the inset: an open Assist window must not push the main window.
    /// A single-instance window (Assist) reopens exactly where the user left it.
    private func restoredSystemFrame(
        _ preferredSystemFrame: CGRect,
        for activity: SceneActivity,
        screenSize: CGSize
    ) -> CGRect {
        guard activity == .webView else { return preferredSystemFrame }
        return adjustedSystemFrame(
            preferredSystemFrame,
            for: screenSize,
            numberOfConnectedScenes: numberOfConnectedScenes(for: activity)
        )
    }

    private func numberOfConnectedScenes(for activity: SceneActivity) -> Int {
        UIApplication.shared.connectedScenes.filter { scene in
            scene.session.configuration.name.flatMap(SceneActivity.init(configurationName:)) == activity
        }.count
    }

    private func centeredFrame(for size: CGSize, screenSize: CGSize) -> CGRect {
        .init(
            x: (screenSize.width - size.width) / 2,
            y: (screenSize.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }
}
