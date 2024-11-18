import AppIntents
import AudioToolbox
import Foundation
import PromiseKit
import Shared

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct PerformAction: AppIntent, CustomIntentMigratedAppIntent, PredictableIntent {
    static let intentClassName = "PerformActionIntent"

    static let title: LocalizedStringResource = "Perform Action"
    static let description = IntentDescription("Performs an action defined in the app")

    @Parameter(title: "Action")
    var action: IntentActionAppEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Perform \(\.$action)")
    }

    static var predictionConfiguration: some IntentPredictionConfiguration {
        IntentPrediction(parameters: \.$action) { action in
            DisplayRepresentation(
                title: "\(action ?? .init(id: "-1", displayString: "Uknown action"))",
                subtitle: "Perform the action"
            )
        }
    }

    @Parameter(
        title: LocalizedStringResource(
            "app_intents.scripts.haptic_confirmation.title",
            defaultValue: "Haptic confirmation"
        ),
        default: false
    )
    var hapticConfirmation: Bool

    func perform() async throws -> some IntentResult {
        guard let intentAction = $action.wrappedValue,
              let action = Current.realm().object(ofType: Action.self, forPrimaryKey: intentAction.id),
              let server = Current.servers.server(for: action),
              let api = Current.api(for: server) else {
            Current.Log.warning("ActionID either does not exist or is not a string in the payload")
            return .result()
        }

        if hapticConfirmation {
            // Unfortunately this is the only 'haptics' that works with widgets
            // ideally in the future this should use CoreHaptics for a better experience
            AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
        }

        try await withCheckedThrowingContinuation { continuation in
            api.HandleAction(actionID: action.ID, source: .AppShortcut).pipe { result in
                switch result {
                case .fulfilled:
                    continuation.resume()
                case let .rejected(error):
                    Current.Log
                        .error(
                            "Failed to run action \(intentAction.displayString), error: \(error.localizedDescription)"
                        )
                    continuation.resume(throwing: error)
                }
            }
        }

        return .result()
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
private extension IntentDialog {
    static func actionParameterDisambiguationIntro(count: Int, action: IntentActionAppEntity) -> Self {
        .init(stringLiteral: L10n.AppIntents.PerformAction.actionParameterDisambiguationIntro(
            count,
            action.displayString
        ))
    }

    static func actionParameterConfirmation(action: IntentActionAppEntity) -> Self {
        .init(stringLiteral: L10n.AppIntents.PerformAction.actionParameterConfirmation(action.displayString))
    }

    static var actionParameterConfiguration: Self {
        .init(stringLiteral: L10n.AppIntents.PerformAction.actionParameterConfiguration)
    }

    static func responseSuccess(action: IntentActionAppEntity) -> Self {
        .init(stringLiteral: L10n.AppIntents.PerformAction.responseSuccess)
    }

    static func responseFailure(error: String) -> Self {
        .init(stringLiteral: L10n.AppIntents.PerformAction.responseFailure(error))
    }
}
