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
    }

    private let requestedPort: NWEndpoint.Port
    private let serviceName: String
    /// Off in tests, which bind loopback and must not put a service on the network — or trip the
    /// local-network permission prompt on the machine running them.
    private let advertisesOverBonjour: Bool
    private let fallbackLocale: Locale
    private let onStateChange: @Sendable (WyomingServerState) -> Void
    private let queue = DispatchQueue(label: "io.home-assistant.wyoming-server", qos: .userInitiated)

    private var listener: NWListener?
    private var connections: [UUID: (handler: WyomingConnection, task: Task<Void, Never>)] = [:]

    init(
        port: NWEndpoint.Port,
        serviceName: String,
        fallbackLocale: Locale,
        advertisesOverBonjour: Bool = true,
        onStateChange: @escaping @Sendable (WyomingServerState) -> Void
    ) {
        self.requestedPort = port
        self.serviceName = serviceName
        self.fallbackLocale = fallbackLocale
        self.advertisesOverBonjour = advertisesOverBonjour
        self.onStateChange = onStateChange
    }

    func start() {
        stop()

        let parameters = NWParameters.tcp
        // The listener is restarted on every foreground, which is well inside the interval a just
        // closed port stays in TIME_WAIT; without this that restart fails with "address in use".
        parameters.allowLocalEndpointReuse = true
        parameters.includePeerToPeer = false

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

        for connection in connections.values {
            // Closing the socket is what ends the handler: its read is parked on a continuation
            // that cancelling the task alone would never resume.
            let handler = connection.handler
            Task { await handler.close() }
            connection.task.cancel()
        }
        connections.removeAll()
    }

    private func accept(_ connection: NWConnection) {
        guard listener != nil, connections.count < Constants.maximumConnections else {
            Current.Log.warning("Wyoming: refusing connection, \(connections.count) already open")
            connection.cancel()
            return
        }

        let id = UUID()
        let handler = WyomingConnection(connection: connection, queue: queue, fallbackLocale: fallbackLocale)
        // The task inherits this actor, so the bookkeeping below runs on it without a hop and the
        // entry is always removed on the same actor that added it.
        let task = Task {
            await handler.run()
            finished(id)
        }
        connections[id] = (handler, task)
    }

    private func finished(_ id: UUID) {
        connections[id] = nil
    }
}
