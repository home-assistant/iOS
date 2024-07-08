import AppIntents
import AudioToolbox
import Foundation
import Shared

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct WidgetGaugeAppIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = .init("widgets.gauge.title", defaultValue: "Actions")
    static let description = IntentDescription(
        .init("widgets.gauge.description", defaultValue: "Display numeric states from Home Assistant in a gauge")
    )

    @Parameter(title: .init("widgets.gauge.parameters.gauge_type", defaultValue: "Gauge Type"), default: .normal)
    var gaugeType: GaugeTypeAppEnum

    @Parameter(title: .init("widgets.gauge.parameters.server", defaultValue: "Server"), default: nil)
    var server: IntentServerAppEntity

    @Parameter(
        title: .init("widgets.gauge.parameters.value_template", defaultValue: "Value Template (0-1)"),
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
        title: .init("widgets.gauge.parameters.value_label_template", defaultValue: "Value Label Template"),
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
        title: .init("widgets.gauge.parameters.min_label_template", defaultValue: "Min Label Template"),
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
        title: .init("widgets.gauge.parameters.max_label_template", defaultValue: "Max Label Template"),
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

    @Parameter(title: .init("widgets.gauge.parameters.run_action", defaultValue: "Run Action"), default: false)
    var runAction: Bool

    @Parameter(title: .init("widgets.gauge.parameters.action", defaultValue: "Action"), default: nil)
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

    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: .init("widgets.gauge.parameters.gauge_type", defaultValue: "GaugeType")
    )
    static var caseDisplayRepresentations: [GaugeTypeAppEnum: DisplayRepresentation] = [
        .normal: DisplayRepresentation(title: .init(
            "widgets.gauge.parameters.gauge_type.normal",
            defaultValue: "Normal"
        )),
        .capacity: DisplayRepresentation(title: .init(
            "widgets.gauge.parameters.gauge_type.capacity",
            defaultValue: "Capacity"
        )),
    ]
}
