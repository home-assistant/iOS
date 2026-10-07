import Foundation
import HAWatchComplications
import Shared

/// Drives a `.complication` row: it holds the poller that keeps the complication's values fresh
/// while the row is on screen, and exposes the resolved render model the row draws.
final class WatchComplicationRowViewModel: ObservableObject {
    /// The rectangular layout to draw, or nil while nothing has been resolved yet — a complication
    /// that was just added and hasn't been fetched, or a legacy one with no rectangular payload.
    @Published private(set) var renderModel: RectangularComplicationRenderModel?
    /// True when the values couldn't be refreshed within the poller's stale interval, so the row can
    /// flag that what it shows may no longer be current — same contract as the entity rows.
    @Published private(set) var isStale = false

    let item: MagicItem
    let itemInfo: MagicItem.Info

    private let poller: WatchComplicationSnapshotPoller

    init(item: MagicItem, itemInfo: MagicItem.Info) {
        self.item = item
        self.itemInfo = itemInfo
        self.poller = WatchComplicationSnapshotPoller(configId: item.id)
    }

    /// The name to show when there is no rectangular layout to render (a legacy complication, or one
    /// that has never been fetched on this watch).
    var fallbackName: String {
        item.name(info: itemInfo)
    }

    /// Rebuilds the complication while the row is on screen; `stopUpdates` (on disappear) ends it.
    func startUpdates() {
        stopUpdates()
        poller.start { [weak self] update in
            self?.renderModel = update.snapshot?.rectangularRenderModel
            self?.isStale = update.isStale
        }
    }

    func stopUpdates() {
        poller.stop()
    }
}
