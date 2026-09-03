import Foundation
import Shared
import WatchKit

/// Keeps the watch app running — and frontmost when the wrist comes back up — across a wrist-down for
/// the operations that must outlive the display timeout: an open Assist screen and a user-started
/// database sync. watchOS has no way to hold the display on; what a `WKExtendedRuntimeSession` buys is
/// that the process keeps running while the screen is dark (instead of suspending seconds later, which
/// stalls the pipeline round-trip or the chunked sync), and that raising the wrist returns to the app
/// rather than the watch face.
///
/// The session type comes from `WKBackgroundModes` in the target's Info.plist (`self-care`, up to
/// 10 minutes). watchOS runs at most one session per app and only starts one from the foreground, so
/// holders are refcounted onto a single session: whoever begins first starts it, and it is invalidated
/// once the last holder ends. A session the system ends early (expiry, another app's session, an error)
/// is simply dropped; the next `begin` starts a fresh one.
///
/// Main-thread only, like `WKApplication`; calls from other threads are hopped over.
final class WatchExtendedRuntimeSessionManager: NSObject {
    /// Why the session is held. Each is one holder, so overlapping operations share one session.
    enum Reason: String {
        case assist
        case databaseSync
    }

    static let shared = WatchExtendedRuntimeSessionManager()

    private var holders: Set<Reason> = []
    /// The session currently starting or running; `nil` once invalidated (by us or the system).
    private var session: WKExtendedRuntimeSession?
    private let makeSession: () -> WKExtendedRuntimeSession
    /// Registered the first time a `begin` arrives before the app is active (a cold launch straight
    /// into Assist from a complication reaches `onAppear` while still inactive). Kept for the
    /// manager's lifetime; the start it triggers is a no-op unless something is held.
    private var didBecomeActiveObserver: NSObjectProtocol?

    init(makeSession: @escaping () -> WKExtendedRuntimeSession = { WKExtendedRuntimeSession() }) {
        self.makeSession = makeSession
        super.init()
    }

    private func onMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }

    private func startSessionIfNeeded() {
        // Nothing to keep alive, or already starting/running on behalf of another holder.
        guard !holders.isEmpty, session == nil else { return }
        // A session can only be started from the foreground (`.mustBeActiveToStartSession` otherwise),
        // so wait for the activation instead of failing the start.
        guard WKApplication.shared().applicationState == .active else {
            Current.Log.info("Extended runtime session deferred until the app is active")
            observeActivation()
            return
        }
        let session = makeSession()
        session.delegate = self
        self.session = session
        Current.Log.info("Starting extended runtime session for \(heldReasons)")
        session.start()
    }

    private func observeActivation() {
        guard didBecomeActiveObserver == nil else { return }
        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: WKApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.startSessionIfNeeded()
        }
    }

    private var heldReasons: [String] {
        holders.map(\.rawValue).sorted()
    }
}

extension WatchExtendedRuntimeSessionManager: WatchExtendedRuntimeSessionHolding {
    func begin(_ reason: Reason) {
        onMain { [self] in
            holders.insert(reason)
            startSessionIfNeeded()
        }
    }

    func end(_ reason: Reason) {
        onMain { [self] in
            holders.remove(reason)
            guard holders.isEmpty, let session else { return }
            Current.Log.info("Ending extended runtime session after \(reason.rawValue)")
            self.session = nil
            session.invalidate()
        }
    }
}

extension WatchExtendedRuntimeSessionManager: WKExtendedRuntimeSessionDelegate {
    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        Current.Log.info("Extended runtime session started for \(heldReasons)")
    }

    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        Current.Log.info("Extended runtime session about to expire; held by \(heldReasons)")
    }

    func extendedRuntimeSession(
        _ extendedRuntimeSession: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
        error: Error?
    ) {
        // Our own `invalidate()` already cleared `session`; only a system-ended session is still current.
        guard extendedRuntimeSession === session else { return }
        session = nil
        let detail = error.map { " (\($0.localizedDescription))" } ?? ""
        Current.Log.info("Extended runtime session invalidated: \(reason.rawValue)\(detail); held by \(heldReasons)")
    }
}
