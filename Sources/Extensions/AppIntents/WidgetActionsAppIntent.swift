import AppIntents
import Foundation

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct WidgetActionsAppIntent: AppIntent, WidgetConfigurationIntent, CustomIntentMigratedAppIntent {
    static let intentClassName = "WidgetActionsIntent"

    static var title: LocalizedStringResource = "Actions"
    static var description = IntentDescription("View and run actions")

    @Parameter(
        title: "Actions",
        size: [
            .systemSmall: 1,
            .systemMedium: 8,
            .systemLarge: 16,
            .systemExtraLarge: 32,
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
        guard let action = $actions.wrappedValue?.first else { return .result() }
        let intent = PerformAction()
        intent.action = action
        let result = try await intent.perform()
        return .result()
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
private extension IntentDialog {
    static var actionsParameterConfiguration: Self {
        "Which actions?"
    }
}
