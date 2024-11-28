import AppIntents
import AudioToolbox
import Foundation
import Shared

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct WidgetSensorsAppIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = .init("widgets.sensors.title", defaultValue: "Sensors")
    static let description = IntentDescription(
        .init("widgets.sensors.title", defaultValue: "Show sensor state.")
    )

    // ATTENTION: Unfortunately these sizes below can't be retrieved dynamically from widget family sizes.
    // Check ``WidgetFamilySizes.swift`` as source of truth
    @Parameter(
        title: .init("app_intents.choose_sensor.title", defaultValue: "Choose Sensor"),
        size: [
            .systemSmall: 3,
            .systemMedium: 6,
            .systemLarge: 12,
            .systemExtraLarge: 20,
        ]
    )
    var sensors: [IntentSensorsAppEntity]?

    static var parameterSummary: some ParameterSummary {
        Summary()
    }
}
