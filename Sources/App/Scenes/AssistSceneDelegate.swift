import Foundation
import Shared
import SwiftUI
import UIKit

@objc class AssistSceneDelegate: BasicSceneDelegate {
    private var server: Server?
    private var preferredPipelineId: String = ""
    private var autoStartRecording: Bool = false

    override func basicConfig(in traitCollection: UITraitCollection) -> BasicSceneDelegate.BasicConfig {
        let server = self.server ?? Current.servers.all.first!
        let assistView = AssistView.build(
            server: server,
            preferredPipelineId: preferredPipelineId,
            autoStartRecording: autoStartRecording
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
            self.preferredPipelineId = userInfo["pipelineId"] as? String ?? ""
            self.autoStartRecording = userInfo["autoStartRecording"] as? Bool ?? false
        }

        super.scene(scene, willConnectTo: session, options: connectionOptions)
    }
}
