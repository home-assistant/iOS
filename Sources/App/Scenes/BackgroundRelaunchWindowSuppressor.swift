import Foundation
import UIKit

final class BackgroundRelaunchWindowSuppressor {
    static let shared = BackgroundRelaunchWindowSuppressor(isSuppressing: UpdateRelaunchMode.launch == .background)

    private(set) var isSuppressing: Bool

    #if targetEnvironment(macCatalyst)
    private var sceneConnectionObserver: NSObjectProtocol?
    #endif

    init(isSuppressing: Bool) {
        self.isSuppressing = isSuppressing
    }

    func windowWasRequested() {
        isSuppressing = false
    }

    func shouldDestroyMainScene(isExplicitRequest: Bool) -> Bool {
        if isExplicitRequest {
            isSuppressing = false
            return false
        }
        return isSuppressing
    }

    func shouldDestroyRestoredScene(configurationName: String?) -> Bool {
        isSuppressing && configurationName != SceneActivity.webView.configurationName
    }

    #if targetEnvironment(macCatalyst)
    func startObservingSceneConnections() {
        guard isSuppressing, sceneConnectionObserver == nil else { return }
        sceneConnectionObserver = NotificationCenter.default.addObserver(
            forName: UIScene.willConnectNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let scene = notification.object as? UIWindowScene,
                  scene.session.role == .windowApplication,
                  shouldDestroyRestoredScene(configurationName: scene.session.configuration.name) else {
                return
            }
            UIApplication.shared.requestSceneSessionDestruction(scene.session, options: nil, errorHandler: nil)
        }
    }
    #endif
}
