import Foundation
import Shared
import UIKit

final class WindowScenesManager {
    static var shared = WindowScenesManager()
    private var windowSizeObservers: [WindowSizeObserver] = []

    func sceneDidBecomeActive(_ scene: UIWindowScene) {
        if #available(macCatalyst 16.0, *) {
            configureSceneSize(scene)
            startObservingScene(scene)
        }
    }

    private func startObservingScene(_ scene: UIWindowScene) {
        let observer = WindowSizeObserver(windowScene: scene)
        windowSizeObservers.append(observer)
    }

    func didDiscardScene(_ scene: UIScene) {
        windowSizeObservers.removeAll(where: { $0.observedScene == scene })
    }

    private func sceneFrameIsValid(_ sceneFrame: CGRect, screenSize: CGSize) -> Bool {
        sceneFrame.height <= screenSize.height && sceneFrame.width <= screenSize.width
    }

    private func adjustedSystemFrame(
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

    @available(macCatalyst 16.0, *)
    private func configureSceneSize(_ scene: UIWindowScene) {
        guard let preferredSystemFrame = ScenesWindowSizeConfig.defaultSceneLatestSystemFrame,
              preferredSystemFrame != .zero else { return }

        let screenSize = scene.screen.bounds.size
        guard sceneFrameIsValid(preferredSystemFrame, screenSize: screenSize) else { return }

        let numberOfConnectedScenes = UIApplication.shared.connectedScenes.count
        let adjustedSystemFrame = adjustedSystemFrame(
            preferredSystemFrame,
            for: screenSize,
            numberOfConnectedScenes: numberOfConnectedScenes
        )

        #if targetEnvironment(macCatalyst)
        scene.requestGeometryUpdate(.Mac(systemFrame: adjustedSystemFrame)) { error in
            Current.Log.info(userInfo: ["Failed to request mac geometry": error.localizedDescription])
        }
        #endif
    }
}
