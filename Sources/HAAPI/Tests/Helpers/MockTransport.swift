import Foundation
@testable import HAAPI

/// A scripted in-memory transport. Incoming server frames are enqueued by the test (or produced
/// by the `onSend` script in reaction to client frames); `failNow()`/`close` end the stream so
/// the connection's receive loop observes a dead socket.
final class MockTransport: HAAPITransport, @unchecked Sendable {
    struct Closed: Error {}

    private let lock = NSLock()
    private var sent: [String] = []
    private var closedCode: URLSessionWebSocketTask.CloseCode?
    private let onSend: (@Sendable (String) -> [String])?
    private let stream: AsyncStream<HAAPITransportMessage>
    private let continuation: AsyncStream<HAAPITransportMessage>.Continuation
    private var iterator: AsyncStream<HAAPITransportMessage>.AsyncIterator

    init(onSend: (@Sendable (String) -> [String])? = nil) {
        self.onSend = onSend
        (self.stream, self.continuation) = AsyncStream<HAAPITransportMessage>.makeStream()
        self.iterator = stream.makeAsyncIterator()
    }

    var sentFrames: [String] { lock.withLock { sent } }
    var closeCode: URLSessionWebSocketTask.CloseCode? { lock.withLock { closedCode } }

    func enqueue(_ frames: String...) {
        for frame in frames {
            continuation.yield(.text(frame))
        }
    }

    /// Simulates the socket dying (server side / network drop).
    func failNow() {
        continuation.finish()
    }

    func send(text: String) async throws {
        lock.withLock { sent.append(text) }
        if let onSend {
            for frame in onSend(text) {
                continuation.yield(.text(frame))
            }
        }
    }

    func receive() async throws -> HAAPITransportMessage {
        if let message = await iterator.next() {
            return message
        }
        throw Closed()
    }

    func close(code: URLSessionWebSocketTask.CloseCode) {
        lock.withLock { closedCode = code }
        continuation.finish()
    }

    /// A transport scripted to complete the auth handshake, then answer every command with
    /// `onCommand` (default: `success: true, result: null`).
    static func authenticating(
        haVersion: String = "2026.7.0",
        onCommand: (@Sendable (_ id: Int, _ type: String, _ frame: [String: Any]) -> [String])? = nil
    ) -> MockTransport {
        let transport = MockTransport(onSend: { text in
            guard let object = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any],
                  let type = object["type"] as? String else { return [] }
            if type == "auth" {
                return ["{\"type\": \"auth_ok\", \"ha_version\": \"\(haVersion)\"}"]
            }
            guard let id = object["id"] as? Int else { return [] }
            if let onCommand {
                return onCommand(id, type, object)
            }
            return ["{\"id\": \(id), \"type\": \"result\", \"success\": true, \"result\": null}"]
        })
        transport.enqueue("{\"type\": \"auth_required\"}")
        return transport
    }
}
