import AppIntents
import AudioToolbox
import Foundation
import Shared

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct WidgetDetailsAppIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = .init("widgets.details.title", defaultValue: "Details")
    static let description = IntentDescription(
        .init("widgets.details.description", defaultValue: "Display states using from Home Assistant in text")
    )

    @Parameter(title: .init("widgets.details.parameters.server", defaultValue: "Server"), default: nil)
    var server: IntentServerAppEntity

    @Parameter(
        title: .init("widgets.details.parameters.upper_template", defaultValue: "Upper Text Template"),
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
        title: .init("widgets.details.parameters.lower_template", defaultValue: "Lower Text Template"),
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
        title: .init(
            "widgets.details.parameters.details_template",
            defaultValue: "Details Text Template (only in rectangular family)"
        ),
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

    @Parameter(
        title: .init("widgets.details.parameters.run_action", defaultValue: "Run Action (only in rectangular family)"),
        default: false
    )
    var runAction: Bool

    @Parameter(
        title: .init("widgets.details.parameters.action", defaultValue: "Action"),
        default: nil
    )
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
