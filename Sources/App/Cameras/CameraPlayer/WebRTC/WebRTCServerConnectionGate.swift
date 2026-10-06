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
    /// Set while a ready state is not to be trusted, until the connection has actually dropped and
    /// come back.
    private var needsReconnectFirst = false

    init(connection: HAConnection) {
        self.connection = connection
    }

    deinit {
        removeObserver()
    }

    /// Calls back with `true` once the connection is ready to carry signaling, or `false` if the
    /// server rejected us and waiting would be pointless. A gate already waiting replaces its
    /// pending handler, so a restarted stream never leaves an older attempt armed behind it.
    ///
    /// `requiringFreshConnection` is for the case where the state cannot be believed: a socket
    /// whose network was taken away still reports itself ready, because nothing has tried to use
    /// it since. Setting it makes the gate ignore the connection it finds and wait for one that
    /// has actually been re-established — the state leaving ready and coming back.
    func whenReady(requiringFreshConnection: Bool = false, _ handler: @escaping (Bool) -> Void) {
        cancel()
        self.handler = handler
        hasRequestedConnect = false
        needsReconnectFirst = requiringFreshConnection

        observer = NotificationCenter.default.addObserver(
            forName: HAConnectionState.didTransitionToStateNotification,
            object: connection,
            queue: .main
        ) { [weak self] _ in
            self?.evaluate(afterTransition: true)
        }

        evaluate(afterTransition: false)
    }

    /// Drops a pending wait without calling back, for a stream that was torn down while waiting.
    func cancel() {
        removeObserver()
        handler = nil
    }

    /// `afterTransition` is set when a state change notification brought us here. HAKit posts
    /// those asynchronously and carries no state in them, so a connection that drops and comes
    /// back within one turn of the queue delivers two notifications that both read ready. The
    /// notification itself is therefore the evidence: the gate was armed while the state read
    /// ready, so any transition since means the connection moved.
    private func evaluate(afterTransition: Bool) {
        guard handler != nil else { return }

        let readiness = WebRTCServerConnectionReadiness(state: connection.state)

        // A connection that has left ready is the reconnect this gate was told to wait for; from
        // here the states mean what they say again.
        if needsReconnectFirst, afterTransition || readiness != .ready {
            needsReconnectFirst = false
        }

        switch readiness {
        case .ready:
            guard !needsReconnectFirst else { return }
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
