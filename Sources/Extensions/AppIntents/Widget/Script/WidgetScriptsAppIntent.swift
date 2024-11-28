import AppIntents
import AudioToolbox
import Foundation
import Shared

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct WidgetScriptsAppIntent: AppIntent, WidgetConfigurationIntent {
    static let title: LocalizedStringResource = .init("widgets.scripts.description", defaultValue: "Run Scripts")

    // ATTENTION: Unfortunately these sizes below can't be retrieved dynamically from widget family sizes.
    // Check ``WidgetFamilySizes.swift`` as source of truth
    @Parameter(
        title: "Scripts",
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
    var scripts: [IntentScriptEntity]?

    @Parameter(
        title: LocalizedStringResource(
            "app_intents.notify_when_run.title",
            defaultValue: "Notify when run"
        ),
        description: LocalizedStringResource(
            "app_intents.notify_when_run.description",
            defaultValue: "Shows notification after executed"
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
            intent.script = .init(
                id: script.id,
                entityId: script.entityId,
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
