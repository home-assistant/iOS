import AppIntents
import AudioToolbox
import Foundation
import Shared

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct WidgetGaugeAppIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "widgets.gauge.title"
    static let description = IntentDescription("widgets.gauge.description")

    @Parameter(title: "widgets.gauge.parameters.gauge_type", default: .normal)
    var gaugeType: GaugeTypeAppEnum

    @Parameter(title: "widgets.gauge.parameters.server", default: nil)
    var server: IntentServerAppEntity

    @Parameter(
        title: "widgets.gauge.parameters.value_template",
        default: "",
        inputOptions: .init(
            capitalizationType: .none,
            multiline: true,
            autocorrect: false,
            smartQuotes: false,
            smartDashes: false
        )
    )
    var valueTemplate: String

    @Parameter(
        title: "widgets.gauge.parameters.value_label_template",
        default: "",
        inputOptions: .init(
            capitalizationType: .none,
            multiline: true,
            autocorrect: false,
            smartQuotes: false,
            smartDashes: false
        )
    )
    var valueLabelTemplate: String

    @Parameter(
        title: "widgets.gauge.parameters.min_label_template",
        default: "",
        inputOptions: .init(
            capitalizationType: .none,
            multiline: true,
            autocorrect: false,
            smartQuotes: false,
            smartDashes: false
        )
    )
    var minTemplate: String

    @Parameter(
        title: "widgets.gauge.parameters.max_label_template",
        default: "",
        inputOptions: .init(
            capitalizationType: .none,
            multiline: true,
            autocorrect: false,
            smartQuotes: false,
            smartDashes: false
        )
    )
    var maxTemplate: String

    @Parameter(title: "widgets.gauge.parameters.run_action", default: false)
    var runAction: Bool

    @Parameter(title: "widgets.gauge.parameters.action", default: nil)
    var action: IntentActionAppEntity?

    static var parameterSummary: some ParameterSummary {
        When(\WidgetGaugeAppIntent.$runAction, .equalTo, true) {
            When(\.$gaugeType, .equalTo, .normal) {
                Summary {
                    \.$gaugeType

                    \.$server
                    \.$valueTemplate

                    \.$valueLabelTemplate
                    \.$minTemplate
                    \.$maxTemplate

                    \.$runAction
                    \.$action
                }
            } otherwise: {
                Summary {
                    \.$gaugeType

                    \.$server
                    \.$valueTemplate

                    \.$valueLabelTemplate

                    \.$runAction
                    \.$action
                }
            }
        } otherwise: {
            When(\.$gaugeType, .equalTo, .normal) {
                Summary {
                    \.$gaugeType

                    \.$server
                    \.$valueTemplate

                    \.$valueLabelTemplate
                    \.$minTemplate
                    \.$maxTemplate

                    \.$runAction
                }
            } otherwise: {
                Summary {
                    \.$gaugeType

                    \.$server
                    \.$valueTemplate

                    \.$valueLabelTemplate

                    \.$runAction
                }
            }
        }
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
enum GaugeTypeAppEnum: String, Codable, Sendable, AppEnum {
    case normal
    case capacity

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "GaugeType")
    static var caseDisplayRepresentations: [GaugeTypeAppEnum: DisplayRepresentation] = [
        .normal: DisplayRepresentation(title: "Normal"),
        .capacity: DisplayRepresentation(title: "Capactity"),
    ]
}
