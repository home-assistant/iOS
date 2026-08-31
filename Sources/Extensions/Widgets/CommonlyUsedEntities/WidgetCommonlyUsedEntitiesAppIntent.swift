import AppIntents
import Foundation
import Shared

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct WidgetCommonlyUsedEntitiesAppIntent: AppIntent, WidgetConfigurationIntent {
    static let title: LocalizedStringResource = .init(
        "widgets.commonly_used_entities.title",
        defaultValue: "Common Controls"
    )

    static var isDiscoverable: Bool = false

    @Parameter(
        title: .init("widgets.param.server.title", defaultValue: "Server")
    )
    var server: IntentServerAppEntity

    /// Left empty by default so the widget keeps showing whatever the usage prediction returns;
    /// picking domains here narrows it to a household's controllable things (lights, covers…)
    /// without having to name every entity.
    @Parameter(
        title: .init(
            "widgets.commonly_used_entities.include_domains.param.title",
            defaultValue: "Include domains"
        ),
        description: .init(
            "widgets.commonly_used_entities.include_domains.param.description",
            defaultValue: "When domains are selected, only entities of those domains are displayed."
        )
    )
    var includedDomains: [WidgetDomainAppEntity]?

    /// Applied after the include list, so a domain named in both is excluded.
    @Parameter(
        title: .init(
            "widgets.commonly_used_entities.exclude_domains.param.title",
            defaultValue: "Exclude domains"
        ),
        description: .init(
            "widgets.commonly_used_entities.exclude_domains.param.description",
            defaultValue: "Entities of the selected domains are never displayed."
        )
    )
    var excludedDomains: [WidgetDomainAppEntity]?

    @Parameter(
        title: .init("widgets.custom.show_last_update_time.param.title", defaultValue: "Show last update time"),
        default: true
    )
    var showLastUpdateTime: Bool

    @Parameter(
        title: .init("widgets.custom.show_states.param.title", defaultValue: "Show states (BETA)"),
        description: .init(
            "widgets.custom.show_states.description",
            defaultValue: "Displaying latest states is not 100% guaranteed, you can give it a try and check the companion App documentation for more information."
        ),
        default: true
    )
    var showStates: Bool

    /// The configured domain rules as the widget applies them to the predicted entity ids.
    var domainFilter: WidgetDomainFilter {
        .init(
            includedDomains: (includedDomains ?? []).map(\.id),
            excludedDomains: (excludedDomains ?? []).map(\.id)
        )
    }

    static var parameterSummary: some ParameterSummary {
        Summary()
    }

    func perform() async throws -> some IntentResult {
        .result()
    }
}
