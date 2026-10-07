import Foundation
import HAKit
import Shared

/// Keeps one entity's state fresh while a screen is visible, by polling the Home Assistant REST API.
///
/// The watch can't hold a WebSocket subscription (see `MagicItem.execute`), so every screen showing
/// live state polls `WatchEntityStateFetcher` instead. This owns that timer, the staleness
/// bookkeeping and the server lookup, so the home rows (`WatchMagicViewRowViewModel`) and the sensor
/// details screen (`WatchEntityDetailsViewModel`) share one implementation.
final class WatchEntityStatePoller {
    /// What the poller knows right now: the last snapshot it managed to fetch (nil until the first
    /// success) and whether that snapshot is too old to be trusted.
    struct Snapshot {
        let entity: HAEntity?
        let isStale: Bool
    }

    private let entityId: String
    private let serverId: String

    private var timer: Timer?
    private var onChange: ((Snapshot) -> Void)?
    private var entity: HAEntity?
    private var isStale = false
    private var lastUpdate: Date?
    private var startedAt: Date?

    static let refreshInterval: TimeInterval = 5
    static let staleInterval: TimeInterval = 10

    init(entityId: String, serverId: String) {
        self.entityId = entityId
        self.serverId = serverId
    }

    deinit {
        timer?.invalidate()
    }

    /// Whether polling is currently running — callers use it to skip work for a screen that's gone.
    var isPolling: Bool {
        timer != nil
    }

    /// Fetches immediately, then every `refreshInterval` until `stop()`, reporting each change on
    /// the main queue. Safe to call again: the previous timer is replaced rather than stacked.
    func start(onChange: @escaping (Snapshot) -> Void) {
        stop()
        self.onChange = onChange
        startedAt = Current.date()
        // Staleness is measured from this start until a fetch succeeds: keeping the previous run's
        // `lastUpdate` would let an old timestamp flip the badge back on right after restarting.
        lastUpdate = nil
        isStale = false
        timer = Timer.scheduledTimer(withTimeInterval: Self.refreshInterval, repeats: true) { [weak self] _ in
            self?.updateStaleness()
            self?.fetch()
        }
        // Hand over what's already known (and the cleared staleness) before the first fetch answers,
        // so a screen coming back stops showing a stale badge it has just outgrown.
        notify()
        fetch()
    }

    /// Ends polling. Any fetch still in flight is discarded, so a late answer can't update a screen
    /// that already disappeared.
    func stop() {
        timer?.invalidate()
        timer = nil
        onChange = nil
    }

    /// One extra fetch shortly from now, to reflect a just-executed action without waiting a whole
    /// interval. Ignored once polling has stopped (the screen disappeared meanwhile).
    func refresh(after delay: TimeInterval) {
        guard isPolling else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, isPolling else { return }
            fetch()
        }
    }

    private func fetch() {
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == serverId }) else {
            return
        }
        WatchEntityStateFetcher.fetchState(entityId: entityId, server: server) { [weak self] fetched in
            // `onChange` is nil once stopped, which also drops answers that arrive too late.
            guard let self, let fetched, onChange != nil else { return }
            entity = fetched
            lastUpdate = Current.date()
            isStale = false
            notify()
        }
    }

    /// Evaluated on every tick: fetches update `lastUpdate` on success only, so a run of failed
    /// polls (or none at all since starting) flips staleness on.
    private func updateStaleness() {
        guard let reference = lastUpdate ?? startedAt else { return }
        let stale = Current.date().timeIntervalSince(reference) >= Self.staleInterval
        guard stale != isStale else { return }
        isStale = stale
        notify()
    }

    private func notify() {
        onChange?(Snapshot(entity: entity, isStale: isStale))
    }
}
