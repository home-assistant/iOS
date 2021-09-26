import Foundation
import Intents
import PromiseKit
import Shared
import UIKit

@available(iOS 14, *)
class WidgetEntitiesIntentHandler: NSObject, WidgetEntitiesIntentHandling {
    func provideEntitiesOptionsCollection(
        for intent: WidgetEntitiesIntent,
        with completion: @escaping (INObjectCollection<IntentEntity>?, Error?) -> Void
    ) {
        firstly {
            Current.apiConnection.caches.states.once().promise
                .map(\.all)
        }
        .sortedValues { $0.entityId < $1.entityId }
        .mapValues(IntentEntity.init(entity:))
        .done { completion(.init(items: $0), nil) }
        .catch { completion(nil, $0) }

    }
}
