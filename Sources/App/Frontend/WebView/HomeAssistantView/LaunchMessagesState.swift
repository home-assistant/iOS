import Foundation
import Shared

/// Queues the launch messages (registrations restored from another device, What's-New, then TestFlight) that
/// `HomeAssistantView` presents over the web frontend. Owned by the web view screen so the sheets can never appear
/// over onboarding — they only exist once a server's frontend is on screen.
@MainActor
final class LaunchMessagesState: ObservableObject {
    enum Message: Identifiable {
        case restoredRegistrations([Server])
        case whatsNew(WhatsNewRelease)
        case testFlight(TestFlightMessage)

        var id: String {
            switch self {
            case .restoredRegistrations: return "restoredRegistrations"
            case let .whatsNew(release): return "whatsNew-\(release.id)"
            case let .testFlight(message): return "testFlight-\(message.id.rawValue)"
            }
        }
    }

    @Published var presented: Message?

    /// Non-private for tests.
    var pending: [Message] = []
    /// Evaluated once per app session — `HomeAssistantView` is recreated on server switches, which
    /// should not re-present the launch messages.
    private static var didEvaluate = false

    func evaluateIfNeeded() {
        guard !Self.didEvaluate else { return }
        Self.didEvaluate = true

        pending = Self.messagesToShow()
        showNext()
    }

    /// The launch messages that apply now, in the order they show. Registrations restored from another device come
    /// first: until they are settled, what this device reports lands on that device in Home Assistant. Asked again on
    /// every launch until answered. Non-private for tests.
    static func messagesToShow() -> [Message] {
        var queue: [Message] = []
        let restoredServers = RegistrationOwnership().serversRegisteredByAnotherDevice()
        if !restoredServers.isEmpty {
            queue.append(.restoredRegistrations(restoredServers))
        }
        if let release = WhatsNewEngine().releaseToShow() {
            queue.append(.whatsNew(release))
        }
        if let message = TestFlightCommunicationEngine().messageToShow() {
            queue.append(.testFlight(message))
        }
        return queue
    }

    /// The prompt for registrations restored from another device, closing itself once they are settled.
    func restoredRegistrationsViewModel(for servers: [Server]) -> RestoredRegistrationsViewModel {
        RestoredRegistrationsViewModel(servers: servers, onFinished: { [weak self] in
            self?.presented = nil
        })
    }

    /// Presents the next queued message, if any. Called on evaluation and on each sheet dismiss so a
    /// single `.sheet` shows them in sequence.
    func showNext() {
        guard presented == nil, !pending.isEmpty else { return }
        presented = pending.removeFirst()
    }

    /// Drops the whole queue when an incoming navigation takes over the screen. Clearing `pending` too
    /// matters: the sheet's `onDismiss` calls `showNext()`, which would otherwise immediately cover the
    /// destination the link just navigated to.
    func dismissAll() {
        pending = []
        presented = nil
    }
}
