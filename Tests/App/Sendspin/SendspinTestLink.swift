import Foundation
@testable import HomeAssistant

/// The server end of a connection to a session, in memory or over a real socket.
protocol SendspinTestLink: AnyObject {
    /// The next message the session sent.
    func nextSent(timeout: TimeInterval) async throws -> SendspinWebSocketFrame
    /// Sends the session a message.
    func deliver(_ kind: SendspinWebSocketFrame.Kind, _ data: Data)
}

extension SendspinTestLink {
    func nextSent() async throws -> SendspinWebSocketFrame {
        try await nextSent(timeout: 5)
    }
}
