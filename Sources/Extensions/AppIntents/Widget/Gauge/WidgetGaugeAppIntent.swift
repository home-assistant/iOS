import AppIntents
import AudioToolbox
import Foundation
import Shared

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct WidgetGaugeAppIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Gauge"
    static let description = IntentDescription("Display numeric states from Home Assistant in a gauge")

    @Parameter(title: "Gauge Type", default: .normal)
    var gaugeType: GaugeTypeAppEnum

    @Parameter(title: "Server", default: nil)
    var server: IntentServerAppEntity

    @Parameter(
        title: "Value Template (0-1)",
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
        title: "Value Label Template",
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
        title: "Max Label Template",
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
        title: "Min Label Template",
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

    @Parameter(title: "Run Action", default: false)
    var runAction: Bool

    @Parameter(title: "Action", default: nil)
    var action: IntentActionAppEntity?

    static var parameterSummary: some ParameterSummary {
        When(\WidgetGaugeAppIntent.$runAction, .equalTo, true) {
            When(\.$gaugeType, .equalTo, .normal) {
                Summary {
                    \.$gaugeType

                    \.$server
                    \.$valueTemplate

                    \.$valueLabelTemplate
                    \.$maxTemplate
                    \.$minTemplate

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
                    \.$maxTemplate
                    \.$minTemplate

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
