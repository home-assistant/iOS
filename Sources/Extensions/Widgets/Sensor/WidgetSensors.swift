import AppIntents
import Intents
import Shared
import SwiftUI
import WidgetKit

@available(iOS 17, *)
struct WidgetSensors: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: WidgetsKind.sensors.rawValue,
            intent: WidgetSensorsAppIntent.self,
            provider: WidgetSensorsAppIntentTimelineProvider()
        ) { timelineEntry in
            WidgetBasicContainerView(
                emptyViewGenerator: {
                    AnyView(WidgetEmptyView(message: L10n.Widgets.Sensors.notConfigured))
                },
                contents: timelineEntry.sensorData.map { sensor in
                    WidgetBasicViewModel(
                        id: sensor.id,
                        title: appendUnitOfMeasurementToValue(sensor: sensor),
                        subtitle: sensor.key,
                        interactionType: .appIntent(.refresh),
                        icon: MaterialDesignIcons(
                            serversideValueNamed: sensor.icon ?? "",
                            fallback: .temperatureKelvinIcon
                        ),
                        useCustomColors: false
                    )
                },
                type: .sensor
            )
        }
        .contentMarginsDisabledIfAvailable()
        .configurationDisplayName(L10n.Widgets.Sensors.title)
        .description(L10n.Widgets.Sensors.description)
        .supportedFamilies(WidgetDetailsTableSupportedFamilies.families)
    }

    private func appendUnitOfMeasurementToValue(sensor: WidgetSensorsEntry.SensorData) -> String {
        "\(sensor.value) \(sensor.unitOfMeasurement ?? "")"
    }
}

enum WidgetDetailsTableSupportedFamilies {
    @available(iOS 17.0, *)
    static let families: [WidgetFamily] = [
        .systemSmall,
        .systemMedium,
        .systemLarge,
        .systemExtraLarge,
    ]
}
