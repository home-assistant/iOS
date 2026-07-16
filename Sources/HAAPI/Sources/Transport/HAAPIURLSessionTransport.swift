import Foundation

/// The production transport: one `URLSessionWebSocketTask` per connection attempt.
/// `@unchecked Sendable` because URLSession tasks are documented thread-safe.
final class HAAPIURLSessionTransport: HAAPITransport, @unchecked Sendable {
    private let task: URLSessionWebSocketTask

    init(request: URLRequest, session: URLSession) {
        self.task = session.webSocketTask(with: request)
        task.resume()
    }

    func send(text: String) async throws {
        try await task.send(.string(text))
    }

    func receive() async throws -> HAAPITransportMessage {
        switch try await task.receive() {
        case let .string(text):
            return .text(text)
        case let .data(data):
            return .data(data)
        @unknown default:
            throw HAAPIError.transport(description: "Unknown websocket message type")
        }
    }

    func close(code: URLSessionWebSocketTask.CloseCode) {
        task.cancel(with: code, reason: nil)
    }
}
