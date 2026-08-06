import AppIntents
import Foundation
import Shared

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct WidgetEnergyAppIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = .init("widgets.energy.title", defaultValue: "Energy")
    static let description = IntentDescription(
        .init("widgets.energy.description", defaultValue: "Show your energy dashboard at a glance.")
    )

    @Parameter(
        title: .init("app_intents.server.title", defaultValue: "Server"),
        default: nil
    )
    var server: IntentServerAppEntity

    @Parameter(
        title: .init("widgets.energy.source.title", defaultValue: "Source"),
        default: .auto
    )
    var source: WidgetEnergySource

    @Parameter(
        title: .init("widgets.energy.period.title", defaultValue: "Period"),
        default: .today
    )
    var period: WidgetEnergyPeriod

    static var parameterSummary: some ParameterSummary {
        Summary()
    }
}
