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
                        interactionType: interactionType(for: sensor),
                        icon: MaterialDesignIcons(
                            serversideValueNamed: sensor.icon ?? "",
                            fallback: .dotsGridIcon
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
        .disfavoredInCarPlayIfAvailable(for: WidgetDetailsTableSupportedFamilies.families)
    }

    private func appendUnitOfMeasurementToValue(sensor: WidgetSensorsEntry.SensorData) -> String {
        "\(sensor.value) \(sensor.unitOfMeasurement ?? "")"
    }

    /// Tapping a sensor opens the app on that entity's more info dialog, matching the behavior of the
    /// other entity based widgets. Placeholder and gallery entries have no entity to open, so they keep
    /// the refresh interaction.
    private func interactionType(for sensor: WidgetSensorsEntry.SensorData) -> WidgetInteractionType {
        guard let entityId = sensor.entityId, let serverId = sensor.serverId,
              let url = AppConstants.openEntityDeeplinkURL(entityId: entityId, serverId: serverId) else {
            return .appIntent(.refresh)
        }
        return .widgetURL(url)
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
