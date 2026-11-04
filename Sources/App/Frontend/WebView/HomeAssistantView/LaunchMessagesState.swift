import Foundation
import Shared

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
    /// should not re-present the launch messages. Non-private for tests.
    static var didEvaluate = false

    func evaluateIfNeeded() {
        guard !Self.didEvaluate else { return }
        Self.didEvaluate = true

        pending = Self.messagesToShow()
        showNext()
    }

    /// Non-private for tests.
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

    func restoredRegistrationsViewModel(
        for servers: [Server],
        ownership: RegistrationOwnership = RegistrationOwnership()
    ) -> RestoredRegistrationsViewModel {
        RestoredRegistrationsViewModel(servers: servers, ownership: ownership, onFinished: { [weak self] in
            self?.presented = nil
        })
    }

    /// Asks about registrations still another device's each time the app comes back, not just once per launch:
    /// what this device reports stays held back until each is settled, and an app kept running by location
    /// updates can go days without a launch. Waits for anything already on screen or queued.
    func askAboutRestoredRegistrationsAgain() {
        guard Self.didEvaluate, presented == nil, pending.isEmpty else { return }
        let servers = RegistrationOwnership().serversRegisteredByAnotherDevice()
        guard !servers.isEmpty else { return }
        presented = .restoredRegistrations(servers)
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
