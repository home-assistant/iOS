import AppIntents
import AudioToolbox
import Foundation
import Shared

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct WidgetScriptsAppIntent: AppIntent, WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Scripts"

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

    static var parameterSummary: some ParameterSummary {
        Summary()
    }

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        if let firstScript = scripts?.first {
            let intent = ScriptAppIntent()
            intent.script = firstScript
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
