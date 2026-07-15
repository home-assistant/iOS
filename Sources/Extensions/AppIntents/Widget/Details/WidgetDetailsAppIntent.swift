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

    @Parameter(title: .init("widgets.content_source.title", defaultValue: "Source"), default: .template)
    var source: WidgetContentSourceAppEnum

    @Parameter(title: .init("widgets.details.parameters.server", defaultValue: "Server"), default: nil)
    var server: IntentServerAppEntity

    /// Entity whose live state drives the widget when `source` is `.entity`. The upper/lower/detail lines
    /// are generated automatically from the entity's name, state and area, no templates required.
    @Parameter(title: .init("widgets.parameters.entity", defaultValue: "Entity"))
    var entity: HAAppEntityAppIntentEntity?

    /// Optional attribute of `entity` to read instead of its state (nil = state), like the watch builder.
    @Parameter(title: .init("widgets.parameters.attribute", defaultValue: "Attribute"))
    var attribute: WidgetDetailsAttributeAppEntity?

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
        title: .init("widgets.details.parameters.run_script", defaultValue: "Run Script (only in rectangular family)"),
        default: false
    )
    var runScript: Bool

    @Parameter(
        title: .init("widgets.details.parameters.script", defaultValue: "Script"),
        default: nil
    )
    var script: IntentScriptEntity?

    @Parameter(
        title: LocalizedStringResource(
            "app_intents.notify_when_run.title",
            defaultValue: "Notify when run"
        ),
        description: LocalizedStringResource(
            "app_intents.notify_when_run.description",
            defaultValue: "Shows notification after executed"
        ),
        default: true
    )
    var showConfirmationNotification: Bool

    static var parameterSummary: some ParameterSummary {
        Switch(\.$source) {
            Case(.entity) {
                When(\WidgetDetailsAppIntent.$runScript, .equalTo, true) {
                    Summary {
                        \.$source
                        \.$entity
                        \.$attribute

                        \.$runScript
                        \.$script
                        \.$showConfirmationNotification
                    }
                } otherwise: {
                    Summary {
                        \.$source
                        \.$entity
                        \.$attribute

                        \.$runScript
                    }
                }
            }
            DefaultCase {
                When(\WidgetDetailsAppIntent.$runScript, .equalTo, true) {
                    Summary {
                        \.$source
                        \.$server
                        \.$upperTemplate
                        \.$lowerTemplate
                        \.$detailsTemplate

                        \.$runScript
                        \.$script
                        \.$showConfirmationNotification
                    }
                } otherwise: {
                    Summary {
                        \.$source
                        \.$server
                        \.$upperTemplate
                        \.$lowerTemplate
                        \.$detailsTemplate

                        \.$runScript
                    }
                }
            }
        }
    }
}
