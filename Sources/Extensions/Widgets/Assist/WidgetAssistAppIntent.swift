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

    /// Legacy single-pipeline selection, kept so widgets configured before multi-pipeline support
    /// (and migrated SiriKit intents) resolve their stored value. Hidden from the configuration UI
    /// by `parameterSummary` — new selections go through `pipelines`.
    @Parameter(title: .init("app_intents.assist.pipeline.title", defaultValue: "Pipeline"))
    var pipeline: AssistPipelineEntity?

    // ATTENTION: Unfortunately these sizes below can't be retrieved dynamically from widget family sizes.
    // Check ``WidgetFamilySizes.swift`` as source of truth
    @Parameter(
        title: .init("app_intents.assist.pipelines.title", defaultValue: "Pipelines"),
        size: [
            .systemSmall: 1,
            .systemMedium: 6,
            .accessoryCircular: 1,
        ]
    )
    var pipelines: [AssistPipelineEntity]?

    @Parameter(
        title: .init("app_intents.controls.assist.parameter.with_voice", defaultValue: "With voice"),
        default: true
    )
    var withVoice: Bool

    static var parameterSummary: some ParameterSummary {
        Summary {
            \.$pipelines
            \.$withVoice
        }
    }
}
