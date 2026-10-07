import AppIntents
import Foundation

/// Which energy series the widget displays. `auto` shows every series the dashboard is configured
/// for; the other cases narrow it to one.
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
enum WidgetEnergySource: String, Codable, Sendable, AppEnum {
    case auto
    case consumption
    case solar
    case battery
    case gas

    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: .init("widgets.energy.source.title", defaultValue: "Source")
    )
    static var caseDisplayRepresentations: [WidgetEnergySource: DisplayRepresentation] = [
        .auto: DisplayRepresentation(title: .init("widgets.energy.source.auto", defaultValue: "Auto")),
        .consumption: DisplayRepresentation(
            title: .init("widgets.energy.source.consumption", defaultValue: "Consumption")
        ),
        .solar: DisplayRepresentation(title: .init("widgets.energy.source.solar", defaultValue: "Solar")),
        .battery: DisplayRepresentation(title: .init("widgets.energy.source.battery", defaultValue: "Battery")),
        .gas: DisplayRepresentation(title: .init("widgets.energy.source.gas", defaultValue: "Gas")),
    ]

    var showsGrid: Bool { self == .auto || self == .consumption }
    var showsSolar: Bool { self == .auto || self == .solar }
    var showsBattery: Bool { self == .auto || self == .battery }
    var showsGas: Bool { self == .auto || self == .gas }
}
