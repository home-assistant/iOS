import Foundation

/// Watches a Now Playing session for the APNs update token the server has to address.
///
/// The token is not available while `session(_:)` is running: the framework associates the
/// representation it returns with a system session only afterwards, so the first look almost always
/// comes back `nil`. Rather than assume it exists, this yields, waits for the hand-off, and then
/// polls for a bounded stretch before giving up — and keeps listening for replacements for as long
/// as the session lives.
///
/// It takes the framework's two accessors as closures so it carries no `NowPlaying` dependency and
/// can be tested without a real session.
@MainActor
public final class RemoteMediaPushTokenObserver {
    private let currentToken: @MainActor () -> Data?
    private let tokenUpdates: @MainActor () -> AsyncStream<Data>
    private let onToken: @MainActor (RemoteMediaPushToken) -> Void
    private let handoffDelay: Duration
    private let recoveryInterval: Duration
    private let recoveryAttempts: Int
    private var task: Task<Void, Never>?
    /// The fingerprint last handed on, so the same token arriving twice is not re-registered.
    private var delivered: String?

    public init(
        handoffDelay: Duration = .milliseconds(250),
        recoveryInterval: Duration = .seconds(1),
        recoveryAttempts: Int = 30,
        currentToken: @escaping @MainActor () -> Data?,
        tokenUpdates: @escaping @MainActor () -> AsyncStream<Data>,
        onToken: @escaping @MainActor (RemoteMediaPushToken) -> Void
    ) {
        self.handoffDelay = handoffDelay
        self.recoveryInterval = recoveryInterval
        self.recoveryAttempts = recoveryAttempts
        self.currentToken = currentToken
        self.tokenUpdates = tokenUpdates
        self.onToken = onToken
    }

    /// Starts observing, at most once. A representation is handed to the framework exactly once, so
    /// a second call is a mistake rather than a reason for a second task.
    public func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            await Task.yield()
            await self?.waitForFirstToken()
            guard let updates = self?.tokenUpdates() else { return }
            for await token in updates {
                guard !Task.isCancelled, let self else { return }
                deliver(token)
            }
        }
    }

    public func cancel() {
        task?.cancel()
        task = nil
    }

    /// Polls for the token the framework attaches after the hand-off, then stops: a session that
    /// still has none after this long is not going to get one, and spinning costs a process with a
    /// 6144 KB ledger more than the token is worth.
    private func waitForFirstToken() async {
        try? await Task.sleep(for: handoffDelay)
        for _ in 0 ..< recoveryAttempts {
            guard !Task.isCancelled else { return }
            if let data = currentToken() {
                deliver(data)
                return
            }
            try? await Task.sleep(for: recoveryInterval)
        }
        // Bound to a local: the logger's interpolation is a closure, and SwiftFormat strips the
        // explicit `self` the compiler then demands.
        let attempts = recoveryAttempts
        RemoteMediaLog.logger.error("no update push token after \(attempts, privacy: .public) attempts")
    }

    private func deliver(_ data: Data) {
        let token = RemoteMediaPushToken(data)
        // A replacement supersedes whatever came before; the same value again is not news.
        guard token.fingerprint != delivered else { return }
        delivered = token.fingerprint
        onToken(token)
    }
}
