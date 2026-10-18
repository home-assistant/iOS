import AppIntents
import Foundation
import Shared
import SwiftUI

// AppIntent that open app needs to have it's target the widget extension AND app target!
@available(iOS 18, watchOS 10, *)
struct AssistAppIntent: AppIntent {
    static var title: LocalizedStringResource = .init(
        "app_intents.controls.assist.title",
        defaultValue: "Assist in app"
    )

    static var openAppWhenRun: Bool = true
    // `openAppWhenRun` is deprecated from iOS 26; both stay until the deployment target passes 26.
    @available(iOS 26.0, watchOS 26.0, *)
    static var supportedModes: IntentModes { .foreground }

    @Parameter(title: .init("app_intents.assist.pipeline.title", defaultValue: "Pipeline"))
    var pipeline: AssistPipelineEntity

    @Parameter(
        title: .init("app_intents.controls.assist.parameter.with_voice", defaultValue: "With voice"),
        default: true
    )
    var withVoice: Bool

    #if !os(watchOS) && !WIDGET_EXTENSION
    /// Split out of `perform()` so the frontend hand-off can be exercised on its own: a foreground
    /// intent traps when its `perform()` runs outside the App Intents runtime.
    static func openAssist(serverId: String, pipelineId: String, withVoice: Bool) {
        DispatchQueue.main.async {
            guard let server = Current.servers.all
                .first(where: { $0.identifier.rawValue == serverId }) ?? Current
                .servers.all.first else { return }
            Current.sceneManager.webViewControllerPromise
                .done { webViewController in
                    webViewController.webViewExternalMessageHandler.showAssist(
                        server: server,
                        pipeline: pipelineId,
                        autoStartRecording: withVoice
                    )
                }
        }
    }
    #endif

    func perform() async throws -> some IntentResult {
        #if os(watchOS)
        // The watch has no web frontend: Assist is its own full-screen cover, owned by the home
        // screen. It always opens ready to record with a text fallback, so `withVoice` has no
        // watch equivalent to honour.
        guard let server = Current.servers.all
            .first(where: { $0.identifier.rawValue == pipeline.serverId }) ?? Current.servers.all.first else {
            return .result()
        }
        WatchAssistLaunch.request(
            serverId: server.identifier.rawValue,
            pipelineId: pipeline.pipelineId ?? ""
        )
        #elseif !WIDGET_EXTENSION
        Self.openAssist(serverId: pipeline.serverId, pipelineId: pipeline.pipelineId ?? "", withVoice: withVoice)
        #endif
        return .result()
    }
}
