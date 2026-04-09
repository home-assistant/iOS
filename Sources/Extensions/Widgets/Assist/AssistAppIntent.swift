import AppIntents
import Foundation
import Shared
import SwiftUI

// AppIntent that open app needs to have it's target the widget extension AND app target!
@available(iOS 18, *)
struct AssistAppIntent: AppIntent {
    static var title: LocalizedStringResource = .init(
        "app_intents.controls.assist.title",
        defaultValue: "Assist in app"
    )

    static var openAppWhenRun: Bool = true

    @Parameter(title: .init("app_intents.assist.pipeline.title", defaultValue: "Pipeline"))
    var pipeline: AssistPipelineEntity

    @Parameter(
        title: .init("app_intents.controls.assist.parameter.with_voice", defaultValue: "With voice"),
        default: true
    )
    var withVoice: Bool

    func perform() async throws -> some IntentResult {
        #if !WIDGET_EXTENSION
        if Current.sceneManager.existingScenes(for: .assist).isEmpty {
            // Mobile context: This is what existing code was doing
            DispatchQueue.main.async {
                guard let server = Current.servers.all
                    .first(where: { $0.identifier.rawValue == pipeline.serverId }) ?? Current
                    .servers.all.first else { return }
                Current.sceneManager.webViewWindowControllerPromise.then(\.webViewControllerPromise)
                    .done { webViewController in
                        webViewController.webViewExternalMessageHandler.showAssist(
                            server: server,
                            pipeline: pipeline.id,
                            autoStartRecording: withVoice
                        )
                    }
            }
        } else {
            // CarPlay context: Signal the CarPlay scene with the payload
            let userInfo: [AnyHashable: Any] = [
                "pipelineId": pipeline.id,
                "serverId": pipeline.serverId,
                "withVoice": withVoice
            ]

            Current.sceneManager.activateAnyScene(for: .assist, with: userInfo)
        }
        #endif
        return .result()
    }
}
