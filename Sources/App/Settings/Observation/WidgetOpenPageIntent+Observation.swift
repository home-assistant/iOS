import HAKit
import PromiseKit
import Shared
import WidgetKit

extension WidgetOpenPageIntent {
    private class Observer {
        var container: PerServerContainer<HACancellable>?

        func start() {
            guard #available(iOS 14, *) else { return }
            container = .init { server in
                let token = Current.api(for: server).connection.caches.panels.subscribe { _, panels in
                    Self.handle(panels: panels, server: server)
                }

                return .init(token) { $1.cancel() }
            }
        }

        enum HandlePanelsError: Error {
            case unchanged
        }

        @available(iOS 14, *)
        private static func handle(panels: HAPanels, server: Server) {
            let key = "last-invalidated-widget-panels-\(server.identifier)"

            firstly {
                Current.diskCache.value(for: key) as Promise<HAPanels>
            }.recover { _ in
                .value(HAPanels(panelsByPath: [:]))
            }.then { current -> Promise<Void> in
                guard panels != current else {
                    return .init(error: HandlePanelsError.unchanged)
                }

                WidgetCenter.shared.reloadTimelines(ofKind: WidgetOpenPageIntent.widgetKind)
                return .value(())
            }.then {
                Current.diskCache.set(panels, for: key)
            }.done {
                Current.Log.info("updated timeline and cache due to server \(server.identifier)")
            }.catch { error in
                if !(error is HandlePanelsError) {
                    Current.Log.verbose("didn't reload panels widget from server \(server.identifier): \(error)")
                }
            }
        }
    }

    private static var observer: Observer?

    static func setupObserver() {
        observer = with(Observer()) {
            $0.start()
        }
    }
}
