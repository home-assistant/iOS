#if os(watchOS)
import Foundation

public extension Notification.Name {
    /// Posted after a direct sync run in which at least one server succeeded, so views reload
    /// their caches from the fresh tables.
    static let watchDirectDatabaseSyncDidFinish = Notification.Name("watchDirectDatabaseSyncDidFinish")
}

public protocol WatchDirectDatabaseSyncing {
    /// Fetches every server's reference data (entity registry, entities, zones, devices, areas,
    /// Assist pipelines) directly over websocket into the watch database. `force` bypasses the
    /// per-server throttle (user-initiated reload).
    @discardableResult
    func syncAll(force: Bool) async -> [WatchDirectSyncOutcome]
    /// Cancels an in-flight run — called before the app backgrounds so no write is caught by the
    /// database suspension.
    func cancel()
}

public final class WatchDirectDatabaseSync: WatchDirectDatabaseSyncing {
    private let baseThrottleSeconds: TimeInterval = 120
    /// Hard ceiling per server so an unreachable host can't hold a reload (or a background
    /// refresh's runtime budget) hostage — HAAPI itself retries forever by design.
    private let perServerTimeout: Duration = .seconds(30)
    private let lock = NSLock()
    private var lastSyncByServer: [String: Date] = [:]
    private var currentTask: Task<[WatchDirectSyncOutcome], Never>?

    public init() {}

    @discardableResult
    public func syncAll(force: Bool) async -> [WatchDirectSyncOutcome] {
        // Coalesce concurrent callers (launch + foreground + reload can overlap) onto one run.
        if let running = lock.withLock({ currentTask }) {
            return await running.value
        }
        let task = Task { await run(force: force) }
        lock.withLock { currentTask = task }
        defer { lock.withLock { currentTask = nil } }
        return await task.value
    }

    public func cancel() {
        lock.withLock { currentTask }?.cancel()
    }

    /// Sequential per server: watch installs are small and this keeps GRDB writer pressure low.
    private func run(force: Bool) async -> [WatchDirectSyncOutcome] {
        var outcomes: [WatchDirectSyncOutcome] = []
        for server in Current.servers.all {
            if Task.isCancelled { break }
            let serverId = server.identifier.rawValue
            guard force || shouldSync(serverId: serverId) else {
                outcomes.append(.init(serverId: serverId, status: .skipped(reason: "throttled")))
                continue
            }
            // A server with no reachable URL is skipped, not failed: its existing rows stay
            // untouched and usable. Common cause: internal-only http URL on a "most secure"
            // server — the watch can't verify the home network, so the user must set the
            // per-server "Always use" URL override in the watch settings.
            guard await server.activeURL() != nil else {
                outcomes.append(.init(
                    serverId: serverId,
                    status: .skipped(reason: WatchDirectSyncOutcome.noReachableURLReason)
                ))
                Current.Log.info(
                    "Direct watch sync skipped server \(server.info.name) (\(serverId)): no reachable URL — "
                        + "consider the watch's per-server URL override"
                )
                continue
            }
            do {
                try await Self.withTimeout(perServerTimeout) { [server] in
                    try await WatchDirectServerSync(server: server).run()
                }
                lock.withLock { lastSyncByServer[serverId] = Date() }
                outcomes.append(.init(serverId: serverId, status: .success))
                Current.Log.info("Direct watch sync succeeded for server \(serverId)")
            } catch {
                outcomes.append(.init(serverId: serverId, status: .failed(String(describing: error))))
                Current.Log.error("Direct watch sync failed for server \(serverId): \(error)")
                Current.clientEventStore.addEvent(.init(
                    text: "Direct watch sync failed for server \(server.info.name)",
                    type: .networkRequest,
                    payload: ["error": String(describing: error)]
                ))
            }
        }
        // One summary line per run so partial coverage (a skipped/failed server among successes)
        // is always visible in the log, not just the per-server events above.
        let summary = outcomes
            .map { outcome -> String in
                switch outcome.status {
                case .success: "\(outcome.serverId)=success"
                case let .skipped(reason): "\(outcome.serverId)=skipped(\(reason))"
                case let .failed(reason): "\(outcome.serverId)=failed(\(reason))"
                }
            }
            .joined(separator: ", ")
        Current.Log.info("Direct watch sync finished: [\(summary.isEmpty ? "no servers" : summary)]")
        updateNoReachableURLServerIds(from: outcomes)
        if outcomes.contains(where: { $0.status == .success }) {
            NotificationCenter.default.post(name: .watchDirectDatabaseSyncDidFinish, object: nil)
        }
        return outcomes
    }

    private func shouldSync(serverId: String) -> Bool {
        guard let last = lock.withLock({ lastSyncByServer[serverId] }) else { return true }
        return Date().timeIntervalSince(last) >= baseThrottleSeconds
    }

    private func updateNoReachableURLServerIds(from outcomes: [WatchDirectSyncOutcome]) {
        var serverIds = WatchUserDefaults.shared.directSyncNoReachableURLServerIds
        for outcome in outcomes {
            switch outcome.status {
            case .success:
                serverIds.remove(outcome.serverId)
            case let .skipped(reason) where reason == WatchDirectSyncOutcome.noReachableURLReason:
                serverIds.insert(outcome.serverId)
            case .skipped, .failed:
                break
            }
        }
        WatchUserDefaults.shared.directSyncNoReachableURLServerIds = serverIds
    }

    private static func withTimeout<T: Sendable>(
        _ timeout: Duration,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw WatchDirectSyncError.timedOut
            }
            guard let result = try await group.next() else {
                throw WatchDirectSyncError.timedOut
            }
            group.cancelAll()
            return result
        }
    }
}
#endif
