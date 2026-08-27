#if !os(watchOS)
import Foundation
import HAIconic
import SwiftUI
import WidgetKit

/// Believable tiles for previews and the component gallery, so a widget drawn without a server
/// still looks like a widget rather than a grid of "Title 1".
public enum WidgetTileSampleData {
    /// Actions, the way a custom or scripts widget lists them.
    public static let actions: [WidgetTileModel] = [
        .init(id: "action-0", title: "Good morning", subtitle: "Scene", icon: .weatherSunsetUpIcon),
        .init(id: "action-1", title: "Kitchen light", subtitle: "On", icon: .lightbulbIcon),
        .init(id: "action-2", title: "Front door", subtitle: "Locked", icon: .lockIcon),
        .init(id: "action-3", title: "Vacuum", subtitle: "Docked", icon: .robotVacuumIcon),
        .init(id: "action-4", title: "Movie night", subtitle: "Script", icon: .movieOpenIcon),
        .init(id: "action-5", title: "Away", subtitle: "Scene", icon: .exitRunIcon),
        .init(id: "action-6", title: "Fan", subtitle: "Off", icon: .fanIcon),
        .init(id: "action-7", title: "Garage", subtitle: "Closed", icon: .garageIcon),
        .init(id: "action-8", title: "Coffee", subtitle: "Script", icon: .coffeeIcon),
        .init(id: "action-9", title: "Blinds", subtitle: "Open", icon: .blindsHorizontalIcon),
        .init(id: "action-10", title: "Doorbell", subtitle: "Idle", icon: .bellIcon),
        .init(id: "action-11", title: "Bedtime", subtitle: "Script", icon: .weatherNightIcon),
    ]

    /// Readings, the way a sensors widget lists them.
    public static let sensors: [WidgetTileModel] = [
        .init(id: "sensor-0", title: "21.4 °C", subtitle: "Living room", icon: .thermometerIcon),
        .init(id: "sensor-1", title: "48 %", subtitle: "Humidity", icon: .waterPercentIcon),
        .init(id: "sensor-2", title: "412 W", subtitle: "Power", icon: .flashIcon),
        .init(id: "sensor-3", title: "78 %", subtitle: "Battery", icon: .batteryHighIcon),
        .init(id: "sensor-4", title: "1013 hPa", subtitle: "Pressure", icon: .gaugeIcon),
        .init(id: "sensor-5", title: "12 µg/m³", subtitle: "Air quality", icon: .airFilterIcon),
    ]

    /// Assist pipelines, the way the Assist widget lists them.
    public static let assistPipelines: [WidgetTileModel] = [
        .init(id: "assist-0", title: "Home Assistant", subtitle: "Home", icon: .messageProcessingOutlineIcon),
        .init(id: "assist-1", title: "Kitchen", subtitle: "Home", icon: .messageProcessingOutlineIcon),
        .init(id: "assist-2", title: "Office", subtitle: "Studio", icon: .messageProcessingOutlineIcon),
    ]

    /// The tiles a family shows, which is what keeps the gallery honest about how a widget fills.
    public static func actions(fitting family: WidgetFamily) -> [WidgetTileModel] {
        Array(actions.prefix(WidgetTileLayout.size(for: family)))
    }

    public static func sensors(fitting family: WidgetFamily) -> [WidgetTileModel] {
        Array(sensors.prefix(WidgetTileLayout.size(for: family)))
    }
}
#endif
