import Foundation
import Intents
import PromiseKit

@available(watchOS 7, *)
class WidgetActionsIntentHandler: NSObject, WidgetActionsIntentHandling {
    func provideActionsOptionsCollection(
        for intent: WidgetActionsIntent,
        with completion: @escaping (INObjectCollection<IntentAction>?, Error?) -> Void
    ) {
        let actions = Current.realm().objects(Action.self).sorted(byKeyPath: #keyPath(Action.Position))
        let performActions = Array(actions.map { IntentAction(action: $0) })
        completion(.init(items: performActions), nil)
    }
}
