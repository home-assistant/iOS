import AppIntents
import AudioToolbox
import Foundation
import Shared

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct WidgetActionsAppIntent: AppIntent, WidgetConfigurationIntent, CustomIntentMigratedAppIntent,
    ProgressReportingIntent {
    static let intentClassName = "WidgetActionsIntent"

    static let title: LocalizedStringResource = "Actions"
    static let description = IntentDescription("View and run actions")

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
        // Unfortunately this is the only 'haptics' that work with widgets
        // ideally in the future this should use CoreHaptics for a better experience
        AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
        progress.totalUnitCount = 100
        progress.completedUnitCount = 70
        guard let action = $actions.wrappedValue?.first else {
            Current.Log.error("No action defined or available for widget")
            return .result()
        }
        let intent = PerformAction()
        intent.action = action
        let _ = try await intent.perform()
        progress.completedUnitCount = 100
        return .result()
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
private extension IntentDialog {
    static var actionsParameterConfiguration: Self {
        .init(stringLiteral: L10n.AppIntents.WidgetAction.actionsParameterConfiguration)
    }
}
