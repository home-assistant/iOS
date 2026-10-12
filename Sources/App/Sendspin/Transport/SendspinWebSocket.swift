import Foundation
import Network
import Shared

/// A server's WebSocket connection to this device, accepted by the listener.
///
/// Sends are handed to the connection synchronously and in call order, which is what keeps the
/// Noise counters on both sides in step. Receives are pulled one message at a time.
final class SendspinWebSocket: SendspinFrameConnection, @unchecked Sendable {
    enum Failure: Error {
        case closed
        case unexpectedMessage
    }

    private let connection: NWConnection
    private let queue: DispatchQueue

    init(connection: NWConnection, queue: DispatchQueue) {
        self.connection = connection
        self.queue = queue
    }

    var remoteDescription: String {
        "\(connection.endpoint)"
    }

    /// Waits for the WebSocket upgrade to finish, or for the connection to fail first.
    func start() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var resumed = false
            connection.stateUpdateHandler = { [weak self] state in
                guard !resumed else {
                    if case .cancelled = state { self?.connection.stateUpdateHandler = nil }
                    return
                }
                switch state {
                case .ready:
                    resumed = true
                    continuation.resume()
                case let .failed(error), let .waiting(error):
                    resumed = true
                    self?.connection.cancel()
                    continuation.resume(throwing: error)
                case .cancelled:
                    resumed = true
                    continuation.resume(throwing: Failure.closed)
                default:
                    break
                }
            }
            connection.start(queue: queue)
        }
    }

    func receive() async throws -> SendspinWebSocketFrame {
        try await withCheckedThrowingContinuation { continuation in
            connection.receiveMessage { content, context, _, error in
                let receivedAt = SendspinClock.nowMicroseconds()
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let metadata = context?.protocolMetadata(definition: NWProtocolWebSocket.definition)
                    as? NWProtocolWebSocket.Metadata else {
                    continuation.resume(throwing: Failure.closed)
                    return
                }
                switch metadata.opcode {
                case .text:
                    continuation.resume(returning: .init(kind: .text, data: content ?? Data(), receivedAt: receivedAt))
                case .binary:
                    continuation.resume(returning: .init(
                        kind: .binary,
                        data: content ?? Data(),
                        receivedAt: receivedAt
                    ))
                case .close:
                    continuation.resume(throwing: Failure.closed)
                default:
                    continuation.resume(throwing: Failure.unexpectedMessage)
                }
            }
        }
    }

    func send(text: Data) {
        send(text, opcode: .text)
    }

    func send(binary: Data) {
        send(binary, opcode: .binary)
    }

    func close() {
        let metadata = NWProtocolWebSocket.Metadata(opcode: .close)
        metadata.closeCode = .protocolCode(.normalClosure)
        let context = NWConnection.ContentContext(identifier: "close", metadata: [metadata])
        connection.send(content: nil, contentContext: context, isComplete: true, completion: .contentProcessed { [
            connection
        ] _ in
            connection.cancel()
        })
    }

    private func send(_ data: Data, opcode: NWProtocolWebSocket.Opcode) {
        let metadata = NWProtocolWebSocket.Metadata(opcode: opcode)
        let context = NWConnection.ContentContext(identifier: "sendspin", metadata: [metadata])
        connection.send(
            content: data,
            contentContext: context,
            isComplete: true,
            completion: .contentProcessed { error in
                if let error {
                    Current.Log.warning("Sendspin: send failed: \(error)")
                }
            }
        )
    }
}
