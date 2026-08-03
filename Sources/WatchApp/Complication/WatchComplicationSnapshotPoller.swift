import Foundation
import Shared

/// Keeps one complication's rendered values fresh while a screen is visible, by rebuilding its
/// snapshot from Home Assistant on a timer.
///
/// The in-list counterpart of `WatchEntityStatePoller`: same interval, same staleness rules, same
/// start-on-appear / stop-on-disappear contract — a complication that isn't on screen costs nothing.
/// It rebuilds through `WatchWidgetComplicationSnapshot.make(config:)`, so the row shows exactly what
/// the face would, and it deliberately does **not** write back to the app group: that write reloads
/// the WidgetKit timelines, whose budget must not be spent every five seconds just because the user
/// happens to be scrolling the list.
final class WatchComplicationSnapshotPoller {
    /// What the poller knows right now: the last snapshot it managed to build (seeded from the stored
    /// one so the row is never blank), and whether that snapshot is too old to be trusted.
    struct Update {
        let snapshot: WatchWidgetComplicationSnapshot?
        let isStale: Bool
    }

    private let configId: String

    private var timer: Timer?
    private var onChange: ((Update) -> Void)?
    private var snapshot: WatchWidgetComplicationSnapshot?
    private var isStale = false
    private var lastUpdate: Date?
    private var startedAt: Date?
    /// Resolved once per run rather than per tick: the home list rebuilds its rows (and so restarts
    /// this poller) whenever the mirrored config changes, so re-reading it every five seconds would
    /// only add SQLite contention with the widget extension.
    private var config: WatchComplicationConfig?
    /// A build in flight. A build can outlast the interval — a template complication renders several
    /// templates per pass — and starting a second one would pile requests onto a server that is
    /// already answering. Skipping instead lets the cadence settle at whatever the server sustains.
    private var isFetching = false

    static let refreshInterval: TimeInterval = 5
    static let staleInterval: TimeInterval = 10

    init(configId: String) {
        self.configId = configId
    }

    deinit {
        timer?.invalidate()
    }

    var isPolling: Bool {
        timer != nil
    }

    /// Rebuilds immediately, then every `refreshInterval` until `stop()`. Safe to call again: the
    /// previous timer is replaced rather than stacked.
    func start(onChange: @escaping (Update) -> Void) {
        stop()
        self.onChange = onChange
        startedAt = Current.date()
        // Staleness is measured from this start until a build succeeds: keeping the previous run's
        // `lastUpdate` would let an old timestamp flip the badge back on right after restarting.
        lastUpdate = nil
        isStale = false
        // `make` rasterizes the complication's Material Design icon, which needs the font registered
        // first. Idempotent, and cheap after the first call.
        MaterialDesignIcons.register()
        config = (try? WatchComplicationConfig.all())?.first(where: { $0.id == configId })
        if snapshot == nil {
            snapshot = WatchWidgetComplicationSnapshotStore.storedSnapshot(id: configId)
        }
        timer = Timer.scheduledTimer(withTimeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            self?.updateStaleness()
            self?.fetch()
        }
        // Hand over what's already known (and the cleared staleness) before the first build answers,
        // so a row coming back stops showing a stale badge it has just outgrown.
        notify()
        fetch()
    }

    /// Ends polling. Any build still in flight is discarded, so a late answer can't update a row that
    /// already disappeared.
    func stop() {
        timer?.invalidate()
        timer = nil
        onChange = nil
    }

    private func fetch() {
        guard !isFetching, let config else { return }
        isFetching = true
        Task { @MainActor [weak self] in
            let result = await WatchWidgetComplicationSnapshot.make(config: config)
            guard let self else { return }
            isFetching = false
            // `onChange` is nil once stopped, which also drops answers that arrive too late. A build
            // that couldn't reach the server keeps the previous values rather than blanking the row.
            guard onChange != nil, result.isLive else { return }
            snapshot = result.snapshot
            lastUpdate = Current.date()
            isStale = false
            notify()
        }
    }

    /// Evaluated on every tick: builds update `lastUpdate` on success only, so a run of failed polls
    /// (or none at all since starting) flips staleness on.
    private func updateStaleness() {
        guard let reference = lastUpdate ?? startedAt else { return }
        let stale = Current.date().timeIntervalSince(reference) >= Self.staleInterval
        guard stale != isStale else { return }
        isStale = stale
        notify()
    }

    private func notify() {
        onChange?(Update(snapshot: snapshot, isStale: isStale))
    }
}
