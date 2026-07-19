import Foundation
import Shared

/// Queues the launch messages (What's-New, then TestFlight) that `HomeAssistantView` presents over the
/// web frontend. Owned by the web view screen so the sheets can never appear over onboarding — they only
/// exist once a server's frontend is on screen.
@MainActor
final class LaunchMessagesState: ObservableObject {
    enum Message: Identifiable {
        case whatsNew(WhatsNewRelease)
        case testFlight(TestFlightMessage)

        var id: String {
            switch self {
            case let .whatsNew(release): return "whatsNew-\(release.id)"
            case let .testFlight(message): return "testFlight-\(message.id.rawValue)"
            }
        }
    }

    @Published var presented: Message?

    private var pending: [Message] = []
    /// Evaluated once per app session — `HomeAssistantView` is recreated on server switches, which
    /// should not re-present the launch messages.
    private static var didEvaluate = false

    func evaluateIfNeeded() {
        guard !Self.didEvaluate else { return }
        Self.didEvaluate = true

        var queue: [Message] = []
        if let release = WhatsNewEngine().releaseToShow() {
            queue.append(.whatsNew(release))
        }
        if let message = TestFlightCommunicationEngine().messageToShow() {
            queue.append(.testFlight(message))
        }
        pending = queue
        showNext()
    }

    /// Presents the next queued message, if any. Called on evaluation and on each sheet dismiss so a
    /// single `.sheet` shows them in sequence.
    func showNext() {
        guard presented == nil, !pending.isEmpty else { return }
        presented = pending.removeFirst()
    }
}
