import AppIntents
import AudioToolbox
import Foundation
import Shared

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct WidgetGaugeAppIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = .init("widgets.gauge.title", defaultValue: "Actions")
    static let description = IntentDescription(
        .init(
            "widgets.gauge.description_with_warning",
            defaultValue: "Display numeric states from Home Assistant in a gauge, ATTENTION: User needs to be admin to use this feature"
        )
    )

    @Parameter(title: .init("widgets.content_source.title", defaultValue: "Source"), default: .template)
    var source: WidgetContentSourceAppEnum

    @Parameter(title: .init("widgets.gauge.parameters.gauge_type", defaultValue: "Gauge Type"), default: .normal)
    var gaugeType: GaugeTypeAppEnum

    @Parameter(title: .init("widgets.gauge.parameters.server", defaultValue: "Server"), default: nil)
    var server: IntentServerAppEntity

    /// Entity whose live state drives the gauge when `source` is `.entity`. The value, labels and range
    /// are generated automatically, no templates required.
    @Parameter(title: .init("widgets.parameters.entity", defaultValue: "Entity"))
    var entity: HAAppEntityAppIntentEntity?

    /// Optional attribute of `entity` to read instead of its state (nil = state), like the watch builder.
    @Parameter(title: .init("widgets.parameters.attribute", defaultValue: "Attribute"))
    var attribute: WidgetGaugeAttributeAppEntity?

    /// Numeric value mapped to an empty gauge (fill 0) when using the entity source.
    @Parameter(title: .init("widgets.gauge.parameters.min_value", defaultValue: "Minimum Value"), default: 0)
    var minValue: Double

    /// Numeric value mapped to a full gauge (fill 1) when using the entity source.
    @Parameter(title: .init("widgets.gauge.parameters.max_value", defaultValue: "Maximum Value"), default: 100)
    var maxValue: Double

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

    @Parameter(
        title: .init("widgets.gauge.parameters.run_script", defaultValue: "Run Script"),
        default: false
    )
    var runScript: Bool

    @Parameter(
        title: .init("widgets.gauge.parameters.script", defaultValue: "Script"),
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
                When(\WidgetGaugeAppIntent.$runScript, .equalTo, true) {
                    Summary {
                        \.$source
                        \.$gaugeType
                        \.$entity
                        \.$attribute

                        \.$minValue
                        \.$maxValue

                        \.$runScript
                        \.$script
                        \.$showConfirmationNotification
                    }
                } otherwise: {
                    Summary {
                        \.$source
                        \.$gaugeType
                        \.$entity
                        \.$attribute

                        \.$minValue
                        \.$maxValue

                        \.$runScript
                    }
                }
            }
            DefaultCase {
                When(\WidgetGaugeAppIntent.$runScript, .equalTo, true) {
                    Switch(\.$gaugeType) {
                        Case(.normal) {
                            Summary {
                                \.$source
                                \.$gaugeType

                                \.$server
                                \.$valueTemplate

                                \.$valueLabelTemplate
                                \.$minTemplate
                                \.$maxTemplate

                                \.$runScript
                                \.$script
                                \.$showConfirmationNotification
                            }
                        }
                        Case(.singleLabel) {
                            Summary {
                                \.$source
                                \.$gaugeType

                                \.$server
                                \.$valueTemplate

                                \.$valueLabelTemplate
                                \.$labelTemplate

                                \.$runScript
                                \.$script
                                \.$showConfirmationNotification
                            }
                        }
                        DefaultCase {
                            Summary {
                                \.$source
                                \.$gaugeType

                                \.$server
                                \.$valueTemplate

                                \.$valueLabelTemplate

                                \.$runScript
                                \.$script
                                \.$showConfirmationNotification
                            }
                        }
                    }
                } otherwise: {
                    Switch(\.$gaugeType) {
                        Case(.normal) {
                            Summary {
                                \.$source
                                \.$gaugeType

                                \.$server
                                \.$valueTemplate

                                \.$valueLabelTemplate
                                \.$minTemplate
                                \.$maxTemplate

                                \.$runScript
                            }
                        }
                        Case(.singleLabel) {
                            Summary {
                                \.$source
                                \.$gaugeType

                                \.$server
                                \.$valueTemplate

                                \.$valueLabelTemplate
                                \.$labelTemplate

                                \.$runScript
                            }
                        }
                        DefaultCase {
                            Summary {
                                \.$source
                                \.$gaugeType

                                \.$server
                                \.$valueTemplate

                                \.$valueLabelTemplate

                                \.$runScript
                            }
                        }
                    }
                }
            }
        }
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
enum GaugeTypeAppEnum: String, Codable, Sendable, AppEnum {
    /// A circular gauge whose tinted arc fills `0…value` over a dim track, with min/max labels.
    case normal

    /// A circular gauge whose tinted arc fills `0…value` over a dim track, with no min/max labels.
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
