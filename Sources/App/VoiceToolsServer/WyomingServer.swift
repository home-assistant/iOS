import Foundation
import Network
import Shared

/// The Wyoming TCP listener: it owns the port, advertises the service over Bonjour, and hands each
/// accepted socket to a `WyomingConnection` running in its own task.
///
/// Advertising is what makes this discoverable — Home Assistant's `wyoming` integration browses for
/// `_wyoming._tcp`, so a device running this shows up as a discovered service rather than having to
/// be added by address.
actor WyomingServer {
    static let bonjourServiceType = "_wyoming._tcp"

    private enum Constants {
        /// Home Assistant opens one connection per request and closes it again, so a handful covers
        /// a retry overlapping a request. The cap is what keeps a misbehaving peer on the local
        /// network from opening sockets until the app runs out of them.
        static let maximumConnections = 8
        /// Keepalive is what makes the stack notice a peer that vanished without closing, rather
        /// than leaving the socket established here forever. The connection's own idle timeout
        /// already covers a peer that is merely quiet; this covers one that is unreachable while
        /// this server is mid-answer and has stopped reading.
        static let keepaliveIdleSeconds = 30
        static let keepaliveIntervalSeconds = 10
        static let keepaliveFailuresBeforeDrop = 3
    }

    private let requestedPort: NWEndpoint.Port
    private let serviceName: String
    /// Off in tests, which bind loopback and must not put a service on the network — or trip the
    /// local-network permission prompt on the machine running them.
    private let advertisesOverBonjour: Bool
    private let fallbackLocale: Locale
    private let makeRecognizer: OnDeviceRecognizerFactory
    private let onStateChange: @Sendable (WyomingServerState) -> Void
    private let queue = DispatchQueue(label: "io.home-assistant.wyoming-server", qos: .userInitiated)

    /// One accepted socket. The sequence orders them by arrival, which is what makes "the oldest"
    /// a thing the server can pick out when it has to make room.
    private struct Accepted {
        let sequence: UInt64
        let handler: WyomingConnection
        let task: Task<Void, Never>
    }

    private var listener: NWListener?
    private var connections: [UUID: Accepted] = [:]
    private var nextSequence: UInt64 = 0

    init(
        port: NWEndpoint.Port,
        serviceName: String,
        fallbackLocale: Locale,
        advertisesOverBonjour: Bool = true,
        makeRecognizer: @escaping OnDeviceRecognizerFactory = systemSpeechRecognizerFactory,
        onStateChange: @escaping @Sendable (WyomingServerState) -> Void
    ) {
        self.requestedPort = port
        self.serviceName = serviceName
        self.fallbackLocale = fallbackLocale
        self.advertisesOverBonjour = advertisesOverBonjour
        self.makeRecognizer = makeRecognizer
        self.onStateChange = onStateChange
    }

    func start() {
        stop()

        let parameters = NWParameters.tcp
        // The listener is restarted on every foreground, which is well inside the interval a just
        // closed port stays in TIME_WAIT; without this that restart fails with "address in use".
        parameters.allowLocalEndpointReuse = true
        parameters.includePeerToPeer = false
        if let tcp = parameters.defaultProtocolStack.internetProtocol as? NWProtocolTCP.Options {
            tcp.enableKeepalive = true
            tcp.keepaliveIdle = Constants.keepaliveIdleSeconds
            tcp.keepaliveInterval = Constants.keepaliveIntervalSeconds
            tcp.keepaliveCount = Constants.keepaliveFailuresBeforeDrop
        }

        let listener: NWListener
        do {
            listener = try NWListener(using: parameters, on: requestedPort)
        } catch {
            Current.Log.error("Wyoming: failed to open port \(requestedPort): \(error)")
            onStateChange(.failed(message: error.localizedDescription))
            return
        }

        if advertisesOverBonjour {
            listener.service = NWListener.Service(name: serviceName, type: Self.bonjourServiceType)
        }
        listener.stateUpdateHandler = { [onStateChange, requestedPort, weak listener] state in
            switch state {
            case .ready:
                // Read back rather than echoed: a port of 0 asks the system to pick one, which the
                // settings screen has to show and a test has to connect to.
                onStateChange(.running(port: listener?.port?.rawValue ?? requestedPort.rawValue))
            case let .failed(error):
                Current.Log.error("Wyoming listener failed: \(error)")
                onStateChange(.failed(message: error.localizedDescription))
            case .cancelled:
                onStateChange(.stopped)
            default:
                break
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            Task { await self?.accept(connection) }
        }

        self.listener = listener
        onStateChange(.starting)
        listener.start(queue: queue)
    }

    func stop() {
        listener?.stateUpdateHandler = nil
        listener?.newConnectionHandler = nil
        listener?.cancel()
        listener = nil

        // Over a copy of the keys: `close` removes the entry it is given, which would otherwise be
        // a mutation in the middle of iterating the dictionary it comes from.
        for id in Array(connections.keys) {
            close(id)
        }
    }

    private func accept(_ connection: NWConnection) {
        guard listener != nil else {
            connection.cancel()
            return
        }

        // Turning the newcomer away would mean a few stale sockets locking Home Assistant out
        // until the app is relaunched — the cap is there to bound memory, not to decide which
        // peer wins. The newest connection is the one with a live request behind it, so room is
        // made for it by dropping the connection that has been sitting here longest.
        while connections.count >= Constants.maximumConnections {
            guard let oldest = connections.min(by: { $0.value.sequence < $1.value.sequence }) else { break }
            Current.Log.warning("Wyoming: \(connections.count) connections open, closing the oldest to make room")
            close(oldest.key)
        }

        let id = UUID()
        let handler = WyomingConnection(
            connection: connection,
            queue: queue,
            fallbackLocale: fallbackLocale,
            makeRecognizer: makeRecognizer
        )
        // The task inherits this actor, so the bookkeeping below runs on it without a hop and the
        // entry is always removed on the same actor that added it.
        let task = Task {
            await handler.run()
            finished(id)
        }
        nextSequence += 1
        connections[id] = Accepted(sequence: nextSequence, handler: handler, task: task)
    }

    private func close(_ id: UUID) {
        guard let accepted = connections.removeValue(forKey: id) else { return }
        // Closing the socket is what ends the handler: its read is parked on a continuation that
        // cancelling the task alone would never resume.
        let handler = accepted.handler
        Task { await handler.close() }
        accepted.task.cancel()
    }

    private func finished(_ id: UUID) {
        connections[id] = nil
    }
}
