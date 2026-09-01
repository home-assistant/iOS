import AppIntents
import Foundation
import Shared
import WidgetKit

@available(iOS 18, *)
struct ControlAssistItem {
    let pipeline: AssistPipelineEntity
    let displayText: String?
}

@available(iOS 18, *)
struct ControlAssistValueProvider: AppIntentControlValueProvider {
    func currentValue(configuration: ControlAssistConfiguration) async throws -> ControlAssistItem {
        .init(pipeline: configuration.pipeline ?? placeholder(), displayText: configuration.displayText)
    }

    func placeholder(for configuration: ControlAssistConfiguration) -> ControlAssistItem {
        .init(pipeline: configuration.pipeline ?? placeholder(), displayText: configuration.displayText)
    }

    func previewValue(configuration: ControlAssistConfiguration) -> ControlAssistItem {
        .init(pipeline: configuration.pipeline ?? placeholder(), displayText: configuration.displayText)
    }

    private func placeholder() -> AssistPipelineEntity {
        AssistPipelineEntity(id: "", serverId: "", name: L10n.Widgets.Controls.Assist.Pipeline.placeholder)
    }
}

@available(iOS 18.0, *)
struct ControlAssistConfiguration: ControlConfigurationIntent {
    static var title: LocalizedStringResource = "Assist"

    @Parameter(
        title: .init("app_intents.assist.pipeline.title", defaultValue: "Pipeline")
    )
    var pipeline: AssistPipelineEntity?
    @Parameter(
        title: .init("app_intents.display_text.title", defaultValue: "Display Text")
    )
    var displayText: String?
}
