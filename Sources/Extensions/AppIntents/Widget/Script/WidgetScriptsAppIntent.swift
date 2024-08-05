import AppIntents
import AudioToolbox
import Foundation
import Shared

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct WidgetScriptsAppIntent: AppIntent, WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Scripts"

    @Parameter(
        title: "Scripts",
        size: WidgetSize.size
    )
    var scripts: [IntentScriptEntity]?

    @Parameter(
        title: LocalizedStringResource(
            "app_intents.scripts.show_confirmation_dialog.title",
            defaultValue: "Confirmation notification"
        ),
        description: LocalizedStringResource(
            "app_intents.scripts.show_confirmation_dialog.description",
            defaultValue: "Shows confirmation notification after executed"
        ),
        default: true
    )
    var showConfirmationDialog: Bool

    static var parameterSummary: some ParameterSummary {
        Summary()
    }

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        if let firstScript = scripts?.first {
            let intent = ScriptAppIntent()
            intent.script = firstScript
            intent.showConfirmationDialog = showConfirmationDialog
            return try await intent.perform()
        } else {
            fatalError("No script available to run in Script widget")
        }
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
private extension IntentDialog {
    static var actionsParameterConfiguration: Self {
        .init(stringLiteral: L10n.AppIntents.WidgetAction.actionsParameterConfiguration)
    }
}
