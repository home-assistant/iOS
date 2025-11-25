import AppIntents
import AudioToolbox
import Foundation
import Shared

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct WidgetDetailsAppIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = .init("widgets.details.title", defaultValue: "Details")
    static let description = IntentDescription(
        .init(
            "widgets.details.description_with_warning",
            defaultValue: "Display states using from Home Assistant in text. ATTENTION: User needs to be admin to use this feature"
        )
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
        title: .init("widgets.details.parameters.run_script", defaultValue: "Run Script"),
        default: false
    )
    var runScript: Bool

    @Parameter(
        title: .init("widgets.details.parameters.script", defaultValue: "Script"),
        default: nil
    )
    var script: IntentScriptEntity?

    static var parameterSummary: some ParameterSummary {
        When(\WidgetDetailsAppIntent.$runScript, .equalTo, true) {
            Summary {
                \.$server
                \.$upperTemplate
                \.$lowerTemplate
                \.$detailsTemplate

                \.$runScript
                \.$script
            }
        } otherwise: {
            Summary {
                \.$server
                \.$upperTemplate
                \.$lowerTemplate
                \.$detailsTemplate

                \.$runScript
            }
        }
    }
}
