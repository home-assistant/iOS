import Foundation
@preconcurrency import Shared

/// Action that opens the complication builder with the entity already picked, so the user lands on
/// the preview and the Customize step instead of the empty source flow. The builder takes any entity
/// (its picker has no domain filter), so this is offered wherever a watch can be paired.
struct WatchComplicationAction: EntityAddToAction {
    var mdiIcon: String { "mdi:watch-variant" }
    var actionType: String { EntityAddToActionType.watchComplication.rawValue }

    func text() -> String {
        L10n.WebView.AddTo.Option.WatchComplication.title
    }
}
