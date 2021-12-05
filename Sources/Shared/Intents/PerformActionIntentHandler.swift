import Foundation
import Intents
import PromiseKit

@available(iOS 13, watchOS 6, *)
class PerformActionIntentHandler: NSObject, PerformActionIntentHandling {
    func handle(
        intent: PerformActionIntent,
        completion: @escaping (PerformActionIntentResponse) -> Void
    ) {
        guard let result = intent.action?.asActionWithUpdated() else {
            completion(.init(code: .failure, userActivity: nil))
            return
        }

        guard let server = Current.servers.server(for: result.action) else {
            completion(.init(code: .failure, userActivity: nil))
            return
        }

        firstly {
            Current.api(for: server).HandleAction(actionID: result.action.ID, source: .SiriShortcut)
        }.done {
            completion(.success(action: result.updated))
        }.catch { error in
            completion(.failure(error: error.localizedDescription))
        }
    }

    func resolveAction(
        for intent: PerformActionIntent, with completion:
        @escaping (IntentActionResolutionResult) -> Void
    ) {
        if let result = intent.action?.asActionWithUpdated() {
            Current.Log.info("using action \(String(describing: result.updated.identifier))")
            completion(.success(with: result.updated))
        } else {
            Current.Log.info("asking for value")
            completion(.needsValue())
        }
    }

    func provideActionOptions(
        for intent: PerformActionIntent,
        with completion: @escaping ([IntentAction]?, Error?) -> Void
    ) {
        let actions = Current.realm().objects(Action.self).sorted(byKeyPath: #keyPath(Action.Position))
        let performActions = Array(actions.map { IntentAction(action: $0) })
        Current.Log.info { () -> String in
            "providing " + performActions.map { action -> String in
                (action.identifier ?? "?") + " (" + action.displayString + ")"
            }.joined(separator: ", ")
        }
        completion(Array(performActions), nil)
    }

    @available(iOS 14, watchOS 7, *)
    func provideActionOptionsCollection(
        for intent: PerformActionIntent,
        with completion: @escaping (INObjectCollection<IntentAction>?, Error?) -> Void
    ) {
        provideActionOptions(for: intent) { actions, error in
            completion(actions.flatMap { .init(items: $0) }, error)
        }
    }
}
