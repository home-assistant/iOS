import Foundation
import Network
import Shared

/// The WebSocket listener Sendspin servers connect to, advertised over Bonjour as
/// `_sendspin._tcp` so Music Assistant finds the device without being told its address.
final class SendspinListener {
    static let serviceType = "_sendspin._tcp"
    static let path = "/sendspin"
    /// The port the specification recommends for players.
    static let defaultPort: UInt16 = 8928

    enum Event {
        case ready(port: UInt16)
        case failed(Error)
        case cancelled
        case connection(NWConnection)
    }

    private let listener: NWListener

    /// - Parameter advertisedName: `nil` in tests, which must not put a service on the network.
    init(port: UInt16, advertisedName: String?, queue: DispatchQueue, onEvent: @escaping (Event) -> Void) throws {
        let parameters = NWParameters.tcp
        let webSocket = NWProtocolWebSocket.Options()
        webSocket.autoReplyPing = true
        parameters.defaultProtocolStack.applicationProtocols.insert(webSocket, at: 0)
        // Restarted on every foreground, well inside the time a just-closed port stays in
        // TIME_WAIT.
        parameters.allowLocalEndpointReuse = true
        parameters.includePeerToPeer = false

        let listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port) ?? .any)
        if let advertisedName {
            var txt = NWTXTRecord()
            txt["path"] = Self.path
            txt["name"] = advertisedName
            listener.service = NWListener.Service(
                name: advertisedName,
                type: Self.serviceType,
                domain: nil,
                txtRecord: txt
            )
        }
        listener.stateUpdateHandler = { [weak listener] state in
            switch state {
            case .ready:
                onEvent(.ready(port: listener?.port?.rawValue ?? port))
            case let .failed(error):
                onEvent(.failed(error))
            case .cancelled:
                onEvent(.cancelled)
            default:
                break
            }
        }
        listener.newConnectionHandler = { connection in
            onEvent(.connection(connection))
        }
        self.listener = listener
        listener.start(queue: queue)
    }

    func cancel() {
        listener.stateUpdateHandler = nil
        listener.newConnectionHandler = nil
        listener.cancel()
    }
}
