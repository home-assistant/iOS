import Foundation
import Shared
import PromiseKit

class PerformActionIntentHandler: NSObject, PerformActionIntentHandling {
    private func action(from intent: PerformActionIntent) -> (IntentAction, Action)? {
        guard let performAction = intent.action, let identifier = performAction.identifier else {
            return nil
        }

        guard let result = Current.realm().object(ofType: Action.self, forPrimaryKey: identifier) else {
            return nil
        }

        return (.init(identifier: result.ID, display: result.Name), result)
    }

    func handle(
        intent: PerformActionIntent,
        completion: @escaping (PerformActionIntentResponse) -> Void
    ) {
        guard let result = action(from: intent) else {
            completion(.init(code: .failure, userActivity: nil))
            return
        }

        guard let api = Current.api() else {
            completion(.init(code: .failureRequiringAppLaunch, userActivity: nil))
            return
        }

        firstly {
            api.HandleAction(actionID: result.1.ID, source: .SiriShortcut)
        }.done {
            completion(.success(action: result.0))
        }.catch { error in
            completion(.failure(error: error.localizedDescription))
        }
    }

    func resolveAction(
        for intent: PerformActionIntent, with completion:
        @escaping (IntentActionResolutionResult) -> Void
    ) {
        if let result = action(from: intent) {
            completion(.success(with: result.0))
        } else {
            completion(.needsValue())
        }
    }

    func provideActionOptions(
        for intent: PerformActionIntent,
        with completion: @escaping ([IntentAction]?, Error?) -> Void
    ) {
        let actions = Current.realm().objects(Action.self).sorted(byKeyPath: #keyPath(Action.Position))
        let performActions = Array(actions.map { IntentAction(identifier: $0.ID, display: $0.Name) })
        Current.Log.info { () -> String in
            return "providing " + performActions.map {
                ($0.identifier ?? "?") + " (" + $0.displayString + ")"
            }.joined(separator: ", ")
        }
        completion(Array(performActions), nil)
    }
}
