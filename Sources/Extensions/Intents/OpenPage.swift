import Intents
import PromiseKit
import Shared

class OpenPageIntentHandler: NSObject, OpenPageIntentHandling, WidgetOpenPageIntentHandling {
    private func fetchOptions(completion: @escaping ([IntentPanel]?, Error?) -> Void) {
        guard let connection = Current.apiConnection else {
            completion(nil, nil)
            return
        }

        firstly {
            connection.send(.panels()).promise
        }.done { panels in
            completion(panels.allPanels.map { .init(panel: $0) }, nil)
        }.catch { error in
            completion(nil, error)
        }
    }

    @available(iOS 14, *)
    func providePagesOptionsCollection(
        for intent: WidgetOpenPageIntent,
        with completion: @escaping (INObjectCollection<IntentPanel>?, Error?) -> Void
    ) {
        fetchOptions { dashboards, error in
            completion(dashboards.flatMap { .init(items: $0) }, error)
        }
    }

    @available(iOS 14, *)
    func providePageOptionsCollection(
        for intent: OpenPageIntent,
        with completion: @escaping (INObjectCollection<IntentPanel>?, Error?) -> Void
    ) {
        fetchOptions { dashboards, error in
            completion(dashboards.flatMap { .init(items: $0) }, error)
        }
    }

    func providePagesOptions(
        for intent: WidgetOpenPageIntent,
        with completion: @escaping ([IntentPanel]?, Error?) -> Void
    ) {
        fetchOptions(completion: completion)
    }

    func providePageOptions(
        for intent: OpenPageIntent,
        with completion: @escaping ([IntentPanel]?, Error?) -> Swift.Void
    ) {
        fetchOptions(completion: completion)
    }
}
