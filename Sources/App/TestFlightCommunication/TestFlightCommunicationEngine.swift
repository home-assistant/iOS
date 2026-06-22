import Shared

final class TestFlightCommunicationEngine {
    private let message: TestFlightMessage?
    private let isTestFlight: () -> Bool
    private let currentPlatform: () -> WhatsNewTargetPlatform
    private let hasSeenMessage: (String) -> Bool

    init(
        message: TestFlightMessage? = TestFlightCommunicationCatalog.message,
        isTestFlight: @escaping () -> Bool = { Current.isTestFlight },
        currentPlatform: @escaping () -> WhatsNewTargetPlatform = { .current },
        hasSeenMessage: @escaping (String) -> Bool = {
            Current.settingsStore.hasSeenTestFlightMessage(messageID: $0)
        }
    ) {
        self.message = message
        self.isTestFlight = isTestFlight
        self.currentPlatform = currentPlatform
        self.hasSeenMessage = hasSeenMessage
    }

    /// Returns the message when it targets the current platform and is unseen, or nil if the user is not on
    /// TestFlight.
    func messageToShow() -> TestFlightMessage? {
        guard isTestFlight(), let message else { return nil }
        let platform = currentPlatform()
        guard message.targetPlatforms.contains(platform), !hasSeenMessage(message.id.rawValue) else {
            return nil
        }
        return message
    }

    /// Returns the message for the current platform regardless of seen state, or nil if not on TestFlight.
    func latestMessage() -> TestFlightMessage? {
        guard isTestFlight(), let message else { return nil }
        let platform = currentPlatform()
        return message.targetPlatforms.contains(platform) ? message : nil
    }

    func markSeen(_ message: TestFlightMessage) {
        Current.settingsStore.markTestFlightMessageSeen(messageID: message.id.rawValue)
    }
}
