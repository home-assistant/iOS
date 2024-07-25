import Intents
import PromiseKit

public class OpenPageIntentHandler: NSObject, OpenPageIntentHandling, WidgetOpenPageIntentHandling {
    public static func cacheKey(serverIdentifier: String) -> String {
        "last-invalidated-widget-panels-\(serverIdentifier)"
    }

    public static func panels(completion: @escaping ([IntentPanel]) -> Void) {
        var intentPanels: [IntentPanel] = []
        var finishedPipesCount = 0
        for server in Current.servers.all {
            (
                Current.diskCache
                    .value(
                        for: OpenPageIntentHandler
                            .cacheKey(serverIdentifier: server.identifier.rawValue)
                    ) as Promise<HAPanels>
            ).pipe { result in
                switch result {
                case let .fulfilled(panels):
                    intentPanels.append(contentsOf: panels.allPanels.map { haPanel in
                        IntentPanel(panel: haPanel, server: server)
                    })
                case let .rejected(error):
                    Current.Log.error("Failed to retrieve HAPanels, error: \(error.localizedDescription)")
                }
                finishedPipesCount += 1

                if finishedPipesCount == Current.servers.all.count {
                    completion(intentPanels)
                }
            }
        }
    }

    private func panelsIntentCollection(completion: @escaping (INObjectCollection<IntentPanel>) -> Void) {
        Self.panels { panels in
            let sections: [INObjectSection<IntentPanel>] = Current.servers.all.map { server in
                .init(
                    title: server.info.name,
                    items: panels.filter({ $0.serverIdentifier == server.identifier.rawValue })
                )
            }
            completion(INObjectCollection<IntentPanel>.init(sections: sections))
        }
    }

    public func providePagesOptionsCollection(
        for intent: WidgetOpenPageIntent,
        with completion: @escaping (INObjectCollection<IntentPanel>?, Error?) -> Void
    ) {
        panelsIntentCollection { collection in
            completion(collection, nil)
        }
    }

    public func providePageOptionsCollection(
        for intent: OpenPageIntent,
        with completion: @escaping (INObjectCollection<IntentPanel>?, Error?) -> Void
    ) {
        panelsIntentCollection { collection in
            completion(collection, nil)
        }
    }

    public func providePagesOptions(
        for intent: WidgetOpenPageIntent,
        with completion: @escaping ([IntentPanel]?, Error?) -> Void
    ) {
        Self.panels { panels in
            completion(panels, nil)
        }
    }

    public func providePageOptions(
        for intent: OpenPageIntent,
        with completion: @escaping ([IntentPanel]?, Error?) -> Swift.Void
    ) {
        Self.panels { panels in
            completion(panels, nil)
        }
    }
}
