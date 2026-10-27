import Foundation

/// The WebSocket a session runs over. A protocol so tests can stand in for a server.
protocol SendspinFrameConnection: AnyObject, Sendable {
    func start() async throws
    func receive() async throws -> SendspinWebSocketFrame
    func send(text: Data)
    func send(binary: Data)
    func close()
}
