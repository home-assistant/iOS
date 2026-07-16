import Foundation

/// One websocket connection attempt. Abstracted from `URLSessionWebSocketTask` so tests can
/// drive the full protocol state machine with a scripted in-memory transport. A transport is
/// never reused after it fails or closes — the connection makes a fresh one per attempt.
public protocol HAAPITransport: Sendable {
    func send(text: String) async throws
    func receive() async throws -> HAAPITransportMessage
    /// Synchronous so teardown paths (`defer`, heartbeat timeout) can always close.
    func close(code: URLSessionWebSocketTask.CloseCode)
}
