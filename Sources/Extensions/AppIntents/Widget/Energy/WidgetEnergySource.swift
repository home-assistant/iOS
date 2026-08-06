import AppIntents
import Foundation

/// Which energy series the widget displays. `auto` shows both grid consumption and solar generation.
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
enum WidgetEnergySource: String, Codable, Sendable, AppEnum {
    case auto
    case consumption
    case solar

    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: .init("widgets.energy.source.title", defaultValue: "Source")
    )
    static var caseDisplayRepresentations: [WidgetEnergySource: DisplayRepresentation] = [
        .auto: DisplayRepresentation(title: .init("widgets.energy.source.auto", defaultValue: "Auto")),
        .consumption: DisplayRepresentation(
            title: .init("widgets.energy.source.consumption", defaultValue: "Consumption")
        ),
        .solar: DisplayRepresentation(title: .init("widgets.energy.source.solar", defaultValue: "Solar")),
    ]

    var showsGrid: Bool { self != .solar }
    var showsSolar: Bool { self != .consumption }
}
