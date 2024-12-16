import Intents
import PromiseKit

public class OpenPageIntentHandler: NSObject, OpenPageIntentHandling, WidgetOpenPageIntentHandling {
    public static func cacheKey(serverIdentifier: String) -> String {
        "last-invalidated-widget-panels-\(serverIdentifier)"
    }

    public static func panels(completion: @escaping ([IntentPanel]) -> Void) {
        var intentPanels: [IntentPanel] = []
        do {
            let panelsPerServer = try AppPanel.panelsPerServer()

            for (server, panels) in panelsPerServer {
                intentPanels.append(contentsOf: panels.map { appPanel in
                    IntentPanel(
                        panel: .init(
                            icon: appPanel.icon,
                            title: appPanel.title,
                            path: appPanel.path,
                            component: appPanel.component,
                            showInSidebar: appPanel.showInSidebar
                        ),
                        server: server
                    )
                })
            }
            completion(intentPanels)
        } catch {
            Current.Log.error("Widget error fetching panels: \(error)")
            completion([])
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
