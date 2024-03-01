//
//  PerformAction.swift
//
//
//  Created by Bruno Pantaleão on 29/02/2024.
//

import Foundation
import AppIntents
import Shared
import PromiseKit

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct PerformAction: AppIntent, CustomIntentMigratedAppIntent, PredictableIntent {
    static let intentClassName = "PerformActionIntent"

    static var title: LocalizedStringResource = "Perform Action"
    static var description = IntentDescription("Performs an action defined in the app")

    @Parameter(title: "Action")
    var action: IntentActionAppEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Perform \(\.$action)")
    }

    static var predictionConfiguration: some IntentPredictionConfiguration {
        IntentPrediction(parameters: (\.$action)) { action in
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
                case .rejected(let error):
                    Current.Log.error("Failed to run action \(intentAction.displayString), error: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                }
            }
        }

        return .result()
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
fileprivate extension IntentDialog {
    static func actionParameterDisambiguationIntro(count: Int, action: IntentActionAppEntity) -> Self {
        "There are \(count) options matching ‘\(action)’."
    }
    static func actionParameterConfirmation(action: IntentActionAppEntity) -> Self {
        "Just to confirm, you wanted ‘\(action)’?"
    }
    static var actionParameterConfiguration: Self {
        "Which action?"
    }
    static func responseSuccess(action: IntentActionAppEntity) -> Self {
        "Done"
    }
    static func responseFailure(error: String) -> Self {
        "Failed: \(error)"
    }
}

