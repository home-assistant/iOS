import AppIntents
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
                title: "\(action!)",
                subtitle: "Perform the action"
            )
        }
    }

    func perform() async throws -> some IntentResult {
        guard let intentAction = $action.wrappedValue,
              let action = Current.realm().object(ofType: Action.self, forPrimaryKey: intentAction.id),
              let server = Current.servers.server(for: action) else {
            Current.Log.warning("ActionID either does not exist or is not a string in the payload")
            return .result()
        }

        try await withCheckedThrowingContinuation { continuation in
            Current.api(for: server).HandleAction(actionID: action.ID, source: .AppShortcut).pipe { result in
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
