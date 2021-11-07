import PromiseKit
import Shared
import WidgetKit

extension WidgetOpenPageIntent {
    static func setupObserver() {
        if #available(iOS 14, *) {
            _ = Current.apiConnection?.caches.panels.subscribe { _, panels in
                WidgetOpenPageIntent.handle(panels: panels)
            }
        }
    }

    enum HandlePanelsError: Error {
        case unchanged
    }

    @available(iOS 14, *)
    private static func handle(panels: HAPanels) {
        let key = "last-invalidated-widget-panels"

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
            Current.Log.info("updated timeline and cache")
        }.catch { error in
            if !(error is HandlePanelsError) {
                Current.Log.error("failed to reload widget: \(error)")
            }
        }
    }
}
