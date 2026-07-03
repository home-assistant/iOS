import Foundation
import WatchConnectivity

/// In-house WatchConnectivity layer that replaces the `Communicator` pod. Owns a single `WCSession`
/// (via an injected seam for testability), fans delegate callbacks out to `Observable`s on their
/// registered queue, and exposes send/transfer entry points.
///
/// Phase 1 is DORMANT: nothing in the app references `shared` or calls `activate()`, so the pod keeps
/// owning `WCSession.default.delegate`. A later phase claims the delegate and rewires call sites.
public final class WatchConnectivityManager: NSObject {
    public static let shared = WatchConnectivityManager()

    let session: WCSessionProtocol?

    let completionLock = NSLock()
    var fileCompletions: [ObjectIdentifier: (Result<Void, Error>) -> Void] = [:]
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

    public var mostRecentlyReceievedContext: HAWatchConnectivity.Context {
        HAWatchConnectivity.Context(content: session?.receivedApplicationContextProxy ?? [:])
    }

    public var mostRecentlySentContext: HAWatchConnectivity.Context {
        HAWatchConnectivity.Context(content: session?.applicationContextProxy ?? [:])
    }

    #if os(iOS)
    public var currentWatchState: HAWatchConnectivity.WatchState {
        guard let session, session.isPairedProxy else { return .notPaired }
        guard session.isWatchAppInstalledProxy else { return .paired(.notInstalled) }
        if session.isComplicationEnabledProxy {
            return .paired(.enabled(
                numberOfComplicationUpdatesAvailableToday: session.remainingComplicationUserInfoTransfersProxy
            ))
        }
        return .paired(.installed)
    }
    #endif

    /// Claim `WCSession.default.delegate` and activate. NOT called during Phase 1 (the pod still owns
    /// the delegate); wired up at the swap phase.
    public func activate() {
        guard let session else { return }
        session.delegateProxy = self
        session.activateProxy()
    }

    func notifyState() { state.notify(sessionState) }
    func notifyReachability() { reachability.notify(currentReachability) }
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
