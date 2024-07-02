import AppIntents
import AudioToolbox
import Foundation
import Shared

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct WidgetDetailsAppIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "widgets.details.title"
    static let description = IntentDescription("widgets.details.description")

    @Parameter(title: "widgets.details.parameters.server", default: nil)
    var server: IntentServerAppEntity

    @Parameter(
        title: "widgets.details.parameters.upper_template",
        default: "",
        inputOptions: .init(
            capitalizationType: .none,
            multiline: true,
            autocorrect: false,
            smartQuotes: false,
            smartDashes: false
        )
    )
    var upperTemplate: String

    @Parameter(
        title: "widgets.details.parameters.lower_template",
        default: "",
        inputOptions: .init(
            capitalizationType: .none,
            multiline: true,
            autocorrect: false,
            smartQuotes: false,
            smartDashes: false
        )
    )
    var lowerTemplate: String

    @Parameter(
        title: "widgets.details.parameters.details_template",
        default: "",
        inputOptions: .init(
            capitalizationType: .none,
            multiline: true,
            autocorrect: false,
            smartQuotes: false,
            smartDashes: false
        )
    )
    var detailsTemplate: String

    @Parameter(title: "widgets.details.parameters.run_action", default: false)
    var runAction: Bool

    @Parameter(title: "widgets.details.parameters.action", default: nil)
    var action: IntentActionAppEntity?

    static var parameterSummary: some ParameterSummary {
        When(\WidgetDetailsAppIntent.$runAction, .equalTo, true) {
            Summary {
                \.$server
                \.$upperTemplate
                \.$lowerTemplate
                \.$detailsTemplate

                \.$runAction
                \.$action
            }
        } otherwise: {
            Summary {
                \.$server
                \.$upperTemplate
                \.$lowerTemplate
                \.$detailsTemplate

                \.$runAction
            }
        }
    }
}
