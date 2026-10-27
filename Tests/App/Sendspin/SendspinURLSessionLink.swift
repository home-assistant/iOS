import Foundation
@testable import HomeAssistant

/// A real WebSocket client connected to the player's listener, playing the server.
final class SendspinURLSessionLink: SendspinTestLink {
    struct Timeout: Error {}

    private let task: URLSessionWebSocketTask

    init(port: UInt16) throws {
        guard let url = URL(string: "ws://127.0.0.1:\(port)\(SendspinListener.path)") else { throw Timeout() }
        self.task = URLSession.shared.webSocketTask(with: url)
        task.resume()
    }

    func nextSent(timeout: TimeInterval) async throws -> SendspinWebSocketFrame {
        try await withThrowingTaskGroup(of: SendspinWebSocketFrame.self) { group in
            group.addTask { [task] in
                switch try await task.receive() {
                case let .string(text):
                    return SendspinWebSocketFrame(kind: .text, data: Data(text.utf8), receivedAt: 0)
                case let .data(data):
                    return SendspinWebSocketFrame(kind: .binary, data: data, receivedAt: 0)
                @unknown default:
                    throw Timeout()
                }
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw Timeout()
            }
            defer { group.cancelAll() }
            guard let frame = try await group.next() else { throw Timeout() }
            return frame
        }
    }

    func deliver(_ kind: SendspinWebSocketFrame.Kind, _ data: Data) {
        let message: URLSessionWebSocketTask.Message = kind == .text
            ? .string(String(decoding: data, as: UTF8.self))
            : .data(data)
        task.send(message) { _ in }
    }

    func close() {
        task.cancel(with: .normalClosure, reason: nil)
    }
}
