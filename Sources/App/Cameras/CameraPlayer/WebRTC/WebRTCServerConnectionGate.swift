import Foundation
import HAKit
import Shared

/// Holds a camera stream back until the server's WebSocket can actually answer it.
///
/// WebRTC signaling runs entirely over that socket, so a stream set up while it is down never gets
/// its client configuration, never sends an offer, and never receives a session — it simply waits.
/// Handing the wait to this gate turns that silence into either a stream that starts as soon as the
/// connection returns, or a failure the player can act on.
final class WebRTCServerConnectionGate {
    private let connection: HAConnection
    private var observer: NSObjectProtocol?
    private var handler: ((Bool) -> Void)?
    /// A socket that stays idle after being asked to connect is one the reconnect logic owns now;
    /// asking again on every state change would only hammer it.
    private var hasRequestedConnect = false

    init(connection: HAConnection) {
        self.connection = connection
    }

    deinit {
        removeObserver()
    }

    /// Calls back with `true` once the connection is ready to carry signaling, or `false` if the
    /// server rejected us and waiting would be pointless. A gate already waiting replaces its
    /// pending handler, so a restarted stream never leaves an older attempt armed behind it.
    func whenReady(_ handler: @escaping (Bool) -> Void) {
        cancel()
        self.handler = handler
        hasRequestedConnect = false

        observer = NotificationCenter.default.addObserver(
            forName: HAConnectionState.didTransitionToStateNotification,
            object: connection,
            queue: .main
        ) { [weak self] _ in
            self?.evaluate()
        }

        evaluate()
    }

    /// Drops a pending wait without calling back, for a stream that was torn down while waiting.
    func cancel() {
        removeObserver()
        handler = nil
    }

    private func evaluate() {
        guard handler != nil else { return }

        switch WebRTCServerConnectionReadiness(state: connection.state) {
        case .ready:
            finish(isReady: true)
        case .unusable:
            finish(isReady: false)
        case .needsConnect:
            // Nothing is bringing the socket back on its own, so ask for it and keep waiting for
            // the state change that follows.
            guard !hasRequestedConnect else { return }
            hasRequestedConnect = true
            Current.Log.info("Camera stream is waiting on a disconnected server, reconnecting it")
            connection.connect()
        case .waiting:
            break
        }
    }

    private func finish(isReady: Bool) {
        guard let handler else { return }
        self.handler = nil
        removeObserver()
        handler(isReady)
    }

    private func removeObserver() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        observer = nil
    }
}
