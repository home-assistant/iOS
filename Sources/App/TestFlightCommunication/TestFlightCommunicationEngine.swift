import Shared
import Version

final class TestFlightCommunicationEngine {
    private let message: TestFlightMessage?
    private let isTestFlight: () -> Bool
    private let currentPlatform: () -> WhatsNewTargetPlatform
    private let currentVersion: () -> Version
    private let currentOSVersion: () -> WhatsNewOSVersion
    private let hasSeenMessage: (String) -> Bool

    init(
        message: TestFlightMessage? = TestFlightCommunicationCatalog.message,
        isTestFlight: @escaping () -> Bool = { Current.isTestFlight },
        currentPlatform: @escaping () -> WhatsNewTargetPlatform = { .current },
        currentVersion: @escaping () -> Version = Current.clientVersion,
        currentOSVersion: @escaping () -> WhatsNewOSVersion = { .current },
        hasSeenMessage: @escaping (String) -> Bool = {
            Current.settingsStore.hasSeenTestFlightMessage(messageID: $0)
        }
    ) {
        self.message = message
        self.isTestFlight = isTestFlight
        self.currentPlatform = currentPlatform
        self.currentVersion = currentVersion
        self.currentOSVersion = currentOSVersion
        self.hasSeenMessage = hasSeenMessage
    }

    /// Returns the message when it is unseen and targets the current platform, app version, and OS version,
    /// or nil if the user is not on TestFlight.
    func messageToShow() -> TestFlightMessage? {
        guard isTestFlight(), let message else { return nil }
        guard !hasSeenMessage(message.id.rawValue), matchesCurrentEnvironment(message) else {
            return nil
        }
        return message
    }

    /// Returns the message for the current environment regardless of seen state, or nil if not on TestFlight.
    func latestMessage() -> TestFlightMessage? {
        guard isTestFlight(), let message else { return nil }
        return matchesCurrentEnvironment(message) ? message : nil
    }

    private func matchesCurrentEnvironment(_ message: TestFlightMessage) -> Bool {
        message.matches(
            platform: currentPlatform(),
            appVersion: WhatsNewAppVersion(currentVersion()),
            osVersion: currentOSVersion()
        )
    }

    func markSeen(_ message: TestFlightMessage) {
        Current.settingsStore.markTestFlightMessageSeen(messageID: message.id.rawValue)
    }
}
