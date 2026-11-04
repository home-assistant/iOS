import AppIntents
import Foundation
import Shared

/// Configuration of the entities widget: a server, the entities to show from it, and whether the
/// footer carries the last update time.
///
/// There is deliberately no "show states" switch — the widget always fetches and shows states.
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct WidgetEntitiesAppIntent: AppIntent, WidgetConfigurationIntent {
    static let title: LocalizedStringResource = .init("widgets.entities.title", defaultValue: "Entities")

    static var isDiscoverable: Bool = false

    @Parameter(
        title: .init("widgets.param.server.title", defaultValue: "Server")
    )
    var server: IntentServerAppEntity

    /// Picked from the same kind of multi-select list as the domain pickers of the commonly used
    /// widget, with no per-family slot count: the user picks as many as they like and the timeline
    /// provider shows as many as the family holds.
    @Parameter(
        title: .init("widgets.entities.param.entities.title", defaultValue: "Entities")
    )
    var entities: [WidgetEntitiesAppEntity]?

    @Parameter(
        title: .init("widgets.custom.show_last_update_time.param.title", defaultValue: "Show last update time"),
        default: true
    )
    var showLastUpdateTime: Bool

    static var parameterSummary: some ParameterSummary {
        Summary()
    }

    func perform() async throws -> some IntentResult {
        .result()
    }
}
