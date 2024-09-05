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
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == pipeline.serverId }) ?? Current
            .servers.all.first else { return .result() }
        Current.sceneManager.webViewWindowControllerPromise.then(\.webViewControllerPromise).done { webViewController in
            webViewController.webViewExternalMessageHandler.showAssist(
                server: server,
                pipeline: pipeline.id,
                autoStartRecording: withVoice
            )
        }
        #endif
        return .result()
    }
}
