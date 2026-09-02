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

    // ATTENTION: Unfortunately these sizes below can't be retrieved dynamically from widget family sizes.
    // Check ``WidgetFamilySizes.swift`` as source of truth
    @Parameter(
        title: .init("widgets.entities.param.entities.title", defaultValue: "Entities"),
        size: [
            .systemSmall: 3,
            .systemMedium: 6,
            .systemLarge: 12,
            .systemExtraLarge: 20,
        ]
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
