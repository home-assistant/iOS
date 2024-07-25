import Intents
import PromiseKit

class OpenPageIntentHandler: NSObject, OpenPageIntentHandling, WidgetOpenPageIntentHandling {
    private func panels() -> [IntentPanel] {
        var intentPanels: [IntentPanel] = []
        Current.servers.all.forEach { server in
            if let panels = (Current.diskCache.value(for: "last-invalidated-widget-panels-\(server.identifier)") as Promise<HAPanels>).value {
                intentPanels.append(contentsOf: panels.allPanels.map { haPanel in
                    IntentPanel(panel: haPanel, server: server)
                })
            }
        }
        return intentPanels
    }

    private func panelsIntentCollection() -> INObjectCollection<IntentPanel> {
        let sections: [INObjectSection<IntentPanel>] = Current.servers.all.map { server in
                .init(title: server.info.name, items: panels().filter({ $0.serverIdentifier == server.identifier.rawValue }))
        }
        return INObjectCollection<IntentPanel>.init(sections: sections)
    }

    func providePagesOptionsCollection(
        for intent: WidgetOpenPageIntent,
        with completion: @escaping (INObjectCollection<IntentPanel>?, Error?) -> Void
    ) {
        completion(panelsIntentCollection(), nil)
    }

    func providePageOptionsCollection(
        for intent: OpenPageIntent,
        with completion: @escaping (INObjectCollection<IntentPanel>?, Error?) -> Void
    ) {
        completion(panelsIntentCollection(), nil)
    }

    func providePagesOptions(
        for intent: WidgetOpenPageIntent,
        with completion: @escaping ([IntentPanel]?, Error?) -> Void
    ) {
        completion(panels(), nil)
    }

    func providePageOptions(
        for intent: OpenPageIntent,
        with completion: @escaping ([IntentPanel]?, Error?) -> Swift.Void
    ) {
        completion(panels(), nil)
    }
}
