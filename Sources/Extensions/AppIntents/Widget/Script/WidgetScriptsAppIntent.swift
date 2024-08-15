import AppIntents
import AudioToolbox
import Foundation
import Shared

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct WidgetScriptsAppIntent: AppIntent, WidgetConfigurationIntent {
    static let title: LocalizedStringResource = .init("widgets.scripts.description", defaultValue: "Run Scripts")

    @Parameter(
        title: "Scripts",
        size: [
            .systemSmall: 2,
            .systemMedium: 4,
            .systemLarge: 10,
            .systemExtraLarge: 20,
            .accessoryInline: 1,
            .accessoryCorner: 1,
            .accessoryCircular: 1,
            .accessoryRectangular: 2,
        ]
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
        guard let scripts else { return .result(value: false) }
        for script in scripts {
            let intent = ScriptAppIntent()
            intent.requiresConfirmationBeforeRun = false
            intent.script = .init(
                id: script.id,
                serverId: script.serverId,
                serverName: script.serverName,
                displayString: script.displayString,
                iconName: script.iconName
            )
            _ = try await intent.perform()
        }

        return .result(value: true)
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
private extension IntentDialog {
    static var actionsParameterConfiguration: Self {
        .init(stringLiteral: L10n.AppIntents.WidgetAction.actionsParameterConfiguration)
    }
}
