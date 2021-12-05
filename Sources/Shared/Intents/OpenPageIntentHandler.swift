import Intents
import PromiseKit

@available(iOS 13, watchOS 6, *)
class OpenPageIntentHandler: NSObject, OpenPageIntentHandling, WidgetOpenPageIntentHandling {
    private func panelsByServer() -> Promise<[(Server, [IntentPanel])]> {
        when(resolved: Current.apis.map { api in
            api.connection.send(.panels()).promise.map { (api.server, $0) }
        }).compactMapValues { result in
            switch result {
            case let .fulfilled((server, panels)):
                return (server, panels.allPanels.map { IntentPanel(panel: $0, server: server) })
            case .rejected:
                return nil
            }
        }
    }

    @available(iOS 14, watchOS 7, *)
    private func panelsIntentCollection() -> Promise<INObjectCollection<IntentPanel>> {
        panelsByServer().map { panelsByServer in
            .init(sections: panelsByServer.map { server, panels in
                INObjectSection(title: server.info.name, items: panels)
            })
        }
    }

    private func panelsArray() -> Promise<[IntentPanel]> {
        panelsByServer().map { panelsByServer in
            panelsByServer.flatMap(\.1)
        }
    }

    @available(iOS 14, watchOS 7, *)
    func providePagesOptionsCollection(
        for intent: WidgetOpenPageIntent,
        with completion: @escaping (INObjectCollection<IntentPanel>?, Error?) -> Void
    ) {
        panelsIntentCollection().done { completion($0, nil) }.catch { completion(nil, $0) }
    }

    @available(iOS 14, watchOS 7, *)
    func providePageOptionsCollection(
        for intent: OpenPageIntent,
        with completion: @escaping (INObjectCollection<IntentPanel>?, Error?) -> Void
    ) {
        panelsIntentCollection().done { completion($0, nil) }.catch { completion(nil, $0) }
    }

    func providePagesOptions(
        for intent: WidgetOpenPageIntent,
        with completion: @escaping ([IntentPanel]?, Error?) -> Void
    ) {
        panelsArray().done { completion($0, nil) }.catch { completion(nil, $0) }
    }

    func providePageOptions(
        for intent: OpenPageIntent,
        with completion: @escaping ([IntentPanel]?, Error?) -> Swift.Void
    ) {
        panelsArray().done { completion($0, nil) }.catch { completion(nil, $0) }
    }
}
