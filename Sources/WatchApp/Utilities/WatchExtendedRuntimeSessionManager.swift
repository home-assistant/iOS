import Foundation
import Shared
import WatchKit

final class WatchExtendedRuntimeSessionManager: NSObject {
    enum Reason: String {
        case assist
        case databaseSync
    }

    static let shared = WatchExtendedRuntimeSessionManager()

    private var holders: Set<Reason> = []
    private var session: WKExtendedRuntimeSession?
    private let makeSession: () -> WKExtendedRuntimeSession
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
        guard !holders.isEmpty, session == nil else { return }
        guard WKApplication.shared().applicationState == .active else {
            observeActivation()
            return
        }
        stopObservingActivation()
        let session = makeSession()
        session.delegate = self
        self.session = session
        Current.Log.info("Starting extended runtime session for \(heldReasons)")
        session.start()
    }

    private func observeActivation() {
        guard didBecomeActiveObserver == nil else { return }
        Current.Log.info("Extended runtime session deferred until the app is active")
        didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: WKApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.startSessionIfNeeded()
        }
    }

    private func stopObservingActivation() {
        guard let didBecomeActiveObserver else { return }
        NotificationCenter.default.removeObserver(didBecomeActiveObserver)
        self.didBecomeActiveObserver = nil
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
        onMain { [self] in
            Current.Log.info("Extended runtime session started for \(heldReasons)")
        }
    }

    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        onMain { [self] in
            Current.Log.info("Extended runtime session about to expire; held by \(heldReasons)")
        }
    }

    func extendedRuntimeSession(
        _ extendedRuntimeSession: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
        error: Error?
    ) {
        onMain { [self] in
            guard extendedRuntimeSession === session else { return }
            session = nil
            let detail = error.map { " (\($0.localizedDescription))" } ?? ""
            Current.Log
                .info("Extended runtime session invalidated: \(reason.rawValue)\(detail); held by \(heldReasons)")
        }
    }
}
