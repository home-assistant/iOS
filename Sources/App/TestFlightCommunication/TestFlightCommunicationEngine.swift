import Shared

final class TestFlightCommunicationEngine {
    private let messages: [TestFlightMessage]
    private let isTestFlight: () -> Bool
    private let currentPlatform: () -> WhatsNewTargetPlatform
    private let hasSeenMessage: (String) -> Bool

    init(
        messages: [TestFlightMessage] = TestFlightCommunicationCatalog.messages,
        isTestFlight: @escaping () -> Bool = { Current.isTestFlight },
        currentPlatform: @escaping () -> WhatsNewTargetPlatform = { .current },
        hasSeenMessage: @escaping (String) -> Bool = {
            Current.settingsStore.hasSeenTestFlightMessage(messageID: $0)
        }
    ) {
        self.messages = messages
        self.isTestFlight = isTestFlight
        self.currentPlatform = currentPlatform
        self.hasSeenMessage = hasSeenMessage
    }

    /// Returns the first unseen message targeting the current platform, or nil if the user is not on TestFlight.
    func messageToShow() -> TestFlightMessage? {
        guard isTestFlight() else { return nil }
        let platform = currentPlatform()
        return messages.first(where: {
            $0.targetPlatforms.contains(platform) && !hasSeenMessage($0.id.rawValue)
        })
    }

    /// Returns the latest message for the current platform regardless of seen state, or nil if not on TestFlight.
    func latestMessage() -> TestFlightMessage? {
        guard isTestFlight() else { return nil }
        let platform = currentPlatform()
        return messages.last(where: { $0.targetPlatforms.contains(platform) })
    }

    func markSeen(_ message: TestFlightMessage) {
        Current.settingsStore.markTestFlightMessageSeen(messageID: message.id.rawValue)
    }
}
