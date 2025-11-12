import Foundation
import Shared
import SwiftUI
import UIKit

@objc class AssistSceneDelegate: BasicSceneDelegate {
    private var server: Server?
    private var preferredPipelineId: String = ""
    private var autoStartRecording: Bool = false

    override func basicConfig(in traitCollection: UITraitCollection) -> BasicSceneDelegate.BasicConfig {
        let server = server ?? Current.servers.all.first!
        let assistView = AssistView.build(
            server: server,
            preferredPipelineId: preferredPipelineId,
            autoStartRecording: autoStartRecording,
            showCloseButton: false
        )
        let hostingController = UIHostingController(rootView: assistView)

        return .init(
            title: "Assist",
            rootViewController: hostingController
        )
    }

    override func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        // Extract parameters from userInfo if available
        if let userActivity = connectionOptions.userActivities.first,
           let userInfo = userActivity.userInfo {
            if let serverIdentifier = userInfo["server"] as? String,
               let server = Current.servers.all.first(where: { $0.identifier.rawValue == serverIdentifier }) {
                self.server = server
            }
            preferredPipelineId = userInfo["pipelineId"] as? String ?? ""
            autoStartRecording = userInfo["autoStartRecording"] as? Bool ?? false
        }

        super.scene(scene, willConnectTo: session, options: connectionOptions)

        #if targetEnvironment(macCatalyst)
        // Center the window on screen
        if let windowScene = scene as? UIWindowScene,
           let screen = windowScene.screen {
            let screenBounds = screen.bounds
            let windowSize = CGSize(width: 600, height: 600)
            let centeredFrame = CGRect(
                x: (screenBounds.width - windowSize.width) / 2,
                y: (screenBounds.height - windowSize.height) / 2,
                width: windowSize.width,
                height: windowSize.height
            )

            if #available(iOS 17.0, *) {
                let geometryPreferences = UIWindowScene.MacGeometryPreferences(systemFrame: centeredFrame)
                windowScene.requestGeometryUpdate(geometryPreferences)
            } else {
                // For iOS 16 and earlier, we can't set the initial frame directly
                // The window will use default positioning
            }
        }
        #endif
    }
}
