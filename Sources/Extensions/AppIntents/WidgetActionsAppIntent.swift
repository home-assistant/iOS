import AppIntents
import Foundation
import Shared

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct WidgetActionsAppIntent: AppIntent, WidgetConfigurationIntent, CustomIntentMigratedAppIntent {
    static let intentClassName = "WidgetActionsIntent"

    static let title: LocalizedStringResource = .init("widgets.actions.title", defaultValue: "Actions")
    static let description = IntentDescription(
        .init("widgets.actions.description", defaultValue: "Perform Home Assistant actions.")
    )

    // ATTENTION: Unfortunately these sizes below can't be retrieved dynamically from widget family sizes.
    // Check ``WidgetFamilySizes.swift`` as source of truth
    @Parameter(
        title: .init("widgets.actions.parameters.action", defaultValue: "Action"),
        size: [
            .systemSmall: 3,
            .systemMedium: 6,
            .systemLarge: 12,
            .systemExtraLarge: 20,
            .accessoryInline: 1,
            .accessoryCorner: 1,
            .accessoryCircular: 1,
            .accessoryRectangular: 2,
        ]
    )
    var actions: [IntentActionAppEntity]?

    static var parameterSummary: some ParameterSummary {
        Summary()
    }

    func perform() async throws -> some IntentResult {
        guard let actions else { return .result() }
        for action in actions {
            let intent = PerformAction()
            intent.action = action
            let _ = try await intent.perform()
        }
        return .result()
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
private extension IntentDialog {
    static var actionsParameterConfiguration: Self {
        .init(stringLiteral: L10n.AppIntents.WidgetAction.actionsParameterConfiguration)
    }
}
