import AppIntents
import Foundation
import Shared

@available(iOS 17.0, *)
struct WidgetAssistAppIntent: WidgetConfigurationIntent, CustomIntentMigratedAppIntent {
    // Carries over configurations from the deprecated SiriKit widget intent
    static let intentClassName = "AssistInAppIntent"

    static let title: LocalizedStringResource = .init("widgets.assist.title", defaultValue: "Assist")
    static let description = IntentDescription(
        .init("widgets.assist.description", defaultValue: "Ask Home Assistant Assist")
    )

    @Parameter(title: .init("app_intents.assist.pipeline.title", defaultValue: "Pipeline"))
    var pipeline: AssistPipelineEntity?

    @Parameter(
        title: .init("app_intents.controls.assist.parameter.with_voice", defaultValue: "With voice"),
        default: true
    )
    var withVoice: Bool

    static var parameterSummary: some ParameterSummary {
        Summary()
    }
}
