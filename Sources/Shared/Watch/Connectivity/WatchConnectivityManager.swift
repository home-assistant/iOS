import Foundation
import WatchConnectivity

/// In-house WatchConnectivity layer that replaces the `Communicator` pod. Owns a single `WCSession`
/// (via an injected seam for testability), fans delegate callbacks out to `Observable`s on their
/// registered queue, and exposes send/transfer entry points.
///
/// The app claims `WCSession.default.delegate` by calling `activate()` at startup —
/// `WatchCommunicatorService` on iOS and `ExtensionDelegate` on watchOS.
public final class WatchConnectivityManager: NSObject {
    public static let shared = WatchConnectivityManager()

    let session: WCSessionProtocol?

    let completionLock = NSLock()
    var fileCompletions: [ObjectIdentifier: (Result<Void, Error>) -> Void] = [:]

    /// In-memory copy of the most recently received application context.
    ///
    /// `WCSession.receivedApplicationContext` is a *blocking* getter: it synchronously waits on
    /// WCSession's internal operation queue, which can stall for tens of seconds while the session is
    /// busy processing incoming transfers (observed in the field as background-refresh watchdog kills
    /// and a generally "hanging" watch app when several syncs ran at once). The cache is primed once
    /// off-main after activation and kept fresh by the `didReceiveApplicationContext` delegate
    /// callback, so `mostRecentlyReceivedContext` never blocks the caller.
    private let receivedContextLock = NSLock()
    private var cachedReceivedContext: [String: Any]?
    #if os(iOS)
    var complicationCompletions: [ObjectIdentifier: (Result<Int, Error>) -> Void] = [:]
    #endif

    public let state = HAWatchConnectivity.Observable<HAWatchConnectivity.SessionState>()
    public let reachability = HAWatchConnectivity.Observable<HAWatchConnectivity.Reachability>()
    public let immediateMessage = HAWatchConnectivity.Observable<HAWatchConnectivity.ImmediateMessage>()
    public let interactiveImmediateMessage = HAWatchConnectivity
        .Observable<HAWatchConnectivity.InteractiveImmediateMessage>()
    public let guaranteedMessage = HAWatchConnectivity.Observable<HAWatchConnectivity.GuaranteedMessage>()
    public let blob = HAWatchConnectivity.Observable<HAWatchConnectivity.Blob>()
    public let context = HAWatchConnectivity.Observable<HAWatchConnectivity.Context>()
    public let complicationInfo = HAWatchConnectivity.Observable<HAWatchConnectivity.ComplicationInfo>()
    #if os(iOS)
    public let watchState = HAWatchConnectivity.Observable<HAWatchConnectivity.WatchState>()
    #endif

    init(session: WCSessionProtocol? = WatchConnectivityManager.defaultSession()) {
        self.session = session
        super.init()
    }

    static func defaultSession() -> WCSessionProtocol? {
        #if targetEnvironment(macCatalyst)
        return nil
        #else
        return WCSession.isSupported() ? WCSession.default : nil
        #endif
    }

    public var isSupported: Bool { session != nil }

    public var currentReachability: HAWatchConnectivity.Reachability {
        guard let session else { return .notReachable }
        return session.isReachableProxy ? .immediatelyReachable : .notReachable
    }

    public var sessionState: HAWatchConnectivity.SessionState {
        guard let session else { return .notActivated }
        switch session.activationStateProxy {
        case .notActivated: return .notActivated
        case .inactive: return .inactive
        case .activated: return .activated
        @unknown default: return .notActivated
        }
    }

    public var hasPendingDataToBeReceived: Bool {
        session?.hasContentPendingProxy ?? false
    }

    public var mostRecentlyReceivedContext: HAWatchConnectivity.Context {
        receivedContextLock.lock()
        let cached = cachedReceivedContext
        receivedContextLock.unlock()
        return HAWatchConnectivity.Context(content: cached ?? [:])
    }

    /// Store the latest received application context; the delegate calls this on receipt and
    /// `activate()` primes it once from the (blocking) session getter off the caller's thread.
    func cacheReceivedContext(_ content: [String: Any], overwrite: Bool = true) {
        receivedContextLock.lock()
        defer { receivedContextLock.unlock() }
        if overwrite || cachedReceivedContext == nil {
            cachedReceivedContext = content
        }
    }

    public var mostRecentlySentContext: HAWatchConnectivity.Context {
        HAWatchConnectivity.Context(content: session?.applicationContextProxy ?? [:])
    }

    #if os(iOS)
    public var currentWatchState: HAWatchConnectivity.WatchState {
        guard let session, session.isPairedProxy else { return .notPaired }
        guard session.isWatchAppInstalledProxy else { return .paired(.notInstalled) }
        let complicationState: HAWatchConnectivity.WatchState.AppState.ComplicationState =
            session.isComplicationEnabledProxy
                ? .enabled(numberOfUpdatesAvailableToday: session.remainingComplicationUserInfoTransfersProxy)
                : .notEnabled
        return .paired(.installed(complicationState, session.watchDirectoryURLProxy))
    }
    #endif

    /// Claim `WCSession.default.delegate` and activate. Called once at startup by
    /// `WatchCommunicatorService` (iOS) and `ExtensionDelegate` (watchOS).
    public func activate() {
        guard let session else { return }
        session.delegateProxy = self
        session.activateProxy()
        // Prime the received-context cache once, away from the caller's thread: the underlying getter
        // blocks on WCSession's operation queue (see `cachedReceivedContext`). A context received via
        // the delegate in the meantime wins over this initial snapshot.
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self, let session = self.session else { return }
            cacheReceivedContext(session.receivedApplicationContextProxy, overwrite: false)
        }
    }

    func notifyState() { state.notify(sessionState) }
    func notifyReachability() { reachability.notify(currentReachability) }

    /// Re-read and re-broadcast the current session + reachability state to all observers.
    ///
    /// watchOS does not reliably emit `sessionReachabilityDidChange` across a suspend→resume, so a
    /// watch app returning to the foreground can be left observing a stale `isReachable` (typically a
    /// false "unreachable") until the app is restarted. Calling this on foreground re-reads the live
    /// value from `WCSession` and pushes it out, so the UI recovers without a restart.
    public func refreshConnectivityState() {
        notifyState()
        notifyReachability()
    }

    #if os(iOS)
    func notifyWatchState() { watchState.notify(currentWatchState) }
    #endif

    /// Resolve a file (blob) transfer completion by handle identity. Called by the delegate with the
    /// concrete `WCSessionFileTransfer`; tests call it with a fake handle.
    func resolveFileTransfer(_ handle: WCTransferHandle, error: Error?) {
        completionLock.lock()
        let completion = fileCompletions.removeValue(forKey: ObjectIdentifier(handle))
        completionLock.unlock()
        guard let completion else { return }
        if let error {
            completion(.failure(HAWatchConnectivity.ConnectivityError.deliveryFailed(underlying: error)))
        } else {
            completion(.success(()))
        }
    }

    #if os(iOS)
    /// Resolve a complication transfer completion by handle identity. On success reports the remaining
    /// daily budget read at finish time.
    func resolveComplicationTransfer(_ handle: WCTransferHandle, error: Error?) {
        completionLock.lock()
        let completion = complicationCompletions.removeValue(forKey: ObjectIdentifier(handle))
        completionLock.unlock()
        guard let completion else { return }
        if let error {
            completion(.failure(HAWatchConnectivity.ConnectivityError.deliveryFailed(underlying: error)))
        } else {
            completion(.success(session?.remainingComplicationUserInfoTransfersProxy ?? 0))
        }
    }
    #endif
}
