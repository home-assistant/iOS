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

    /// Label used to populate the `currentValueLabel` closure passed to a Gauge.
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

    /// Label used to populate the default closure passed to a Gauge. This is shown below the value label template
    /// for the `singleLabel` gauge type.
    @Parameter(
        title: .init("widgets.gauge.parameters.label_template", defaultValue: "Label Template"),
        default: "",
        inputOptions: .init(
            capitalizationType: .none,
            multiline: true,
            autocorrect: false,
            smartQuotes: false,
            smartDashes: false
        )
    )
    var labelTemplate: String

    /// Label used to populate the `minimumValueLabel` closure passed to a Gauge.
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

    /// Label used to populate the `maximumValueLabel` closure passed to a Gauge.
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
            Switch(\.$gaugeType) {
                Case(.normal) {
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
                }
                Case(.singleLabel) {
                    Summary {
                        \.$gaugeType

                        \.$server
                        \.$valueTemplate

                        \.$valueLabelTemplate
                        \.$labelTemplate

                        \.$runAction
                        \.$action
                    }
                }
                DefaultCase {
                    Summary {
                        \.$gaugeType

                        \.$server
                        \.$valueTemplate

                        \.$valueLabelTemplate

                        \.$runAction
                        \.$action
                    }
                }
            }
        } otherwise: {
            Switch(\.$gaugeType) {
                Case(.normal) {
                    Summary {
                        \.$gaugeType

                        \.$server
                        \.$valueTemplate

                        \.$valueLabelTemplate
                        \.$minTemplate
                        \.$maxTemplate

                        \.$runAction
                    }
                }
                Case(.singleLabel) {
                    Summary {
                        \.$gaugeType

                        \.$server
                        \.$valueTemplate

                        \.$valueLabelTemplate
                        \.$labelTemplate

                        \.$runAction
                    }
                }
                DefaultCase {
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
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
enum GaugeTypeAppEnum: String, Codable, Sendable, AppEnum {
    /// Represents a `Gauge` with style `accessoryCircular` and min/max labels.
    case normal

    /// Represents a `Gauge` with style `accessoryCircular` that has no min / max labels set.
    case singleLabel

    /// Represents a `Gauge` with style `accessoryCircularCapacity`.
    case capacity

    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: .init("widgets.gauge.parameters.gauge_type", defaultValue: "GaugeType")
    )
    static var caseDisplayRepresentations: [GaugeTypeAppEnum: DisplayRepresentation] = [
        .normal: DisplayRepresentation(title: .init(
            "widgets.gauge.parameters.gauge_type.normal",
            defaultValue: "Normal"
        )),
        .singleLabel: DisplayRepresentation(title: .init(
            "widgets.gauge.parameters.gauge_type.singleLabel",
            defaultValue: "Normal (single label)"
        )),
        .capacity: DisplayRepresentation(title: .init(
            "widgets.gauge.parameters.gauge_type.capacity",
            defaultValue: "Capacity"
        )),
    ]
}
