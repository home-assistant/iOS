#if targetEnvironment(macCatalyst)
import Shared
import SwiftUI
import UIKit

@objc class OnboardingSceneDelegate: BasicSceneDelegate {
    override func basicConfig(in traitCollection: UITraitCollection) -> BasicSceneDelegate.BasicConfig {
        let onboardingView = OnboardingNavigationView(onboardingStyle: .secondary)
        let hostingController = UIHostingController(rootView: onboardingView)

        return .init(
            title: "Add Server",
            rootViewController: hostingController
        )
    }

    override func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        super.scene(scene, willConnectTo: session, options: connectionOptions)

        #if targetEnvironment(macCatalyst)
        // Configure window size for onboarding
        if let windowScene = scene as? UIWindowScene {
            let screen = windowScene.screen
            let screenBounds = screen.bounds
            let windowSize = CGSize(width: 800, height: 600)
            let centeredFrame = CGRect(
                x: (screenBounds.width - windowSize.width) / 2,
                y: (screenBounds.height - windowSize.height) / 2,
                width: windowSize.width,
                height: windowSize.height
            )

            if #available(macCatalyst 16.0, *) {
                windowScene.requestGeometryUpdate(.Mac(systemFrame: centeredFrame)) { error in
                    Current.Log.info(["Failed to request geometry": error.localizedDescription])
                }
            }
        }
        #endif
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Clean up when scene is destroyed
        Current.Log.info("Onboarding scene disconnected")
        window = nil
        self.scene = nil
    }
}
#endif
