import Foundation
import AppIntents

// OpenIntent needs to have it's target the widget extension AND app target!
@available(iOS 18, *)
struct AssistAppIntent: OpenIntent {
    static var title: LocalizedStringResource = "Assist"

    @Parameter(title: "Pipeline")
    var target: AssistPipelineEntity
}
