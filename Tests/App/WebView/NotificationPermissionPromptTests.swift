@testable import HomeAssistant
@testable import Shared
import Testing
import UserNotifications

@Suite(.serialized)
struct NotificationPermissionPromptTests {
    private func withPromptAnswered(_ answered: Bool, _ body: () -> Void) {
        let previous = Current.settingsStore.notificationPermissionPromptAnswered
        defer { Current.settingsStore.notificationPermissionPromptAnswered = previous }
        Current.settingsStore.notificationPermissionPromptAnswered = answered
        body()
    }

    @Test func promptsWhileTheSystemHasNotDecidedAndThePromptWasNeverAnswered() {
        withPromptAnswered(false) {
            #expect(WebViewController.needsNotificationPermissionPrompt(status: .notDetermined))
            #expect(WebViewController.needsNotificationPermissionPrompt(status: .provisional))
            #expect(!WebViewController.needsNotificationPermissionPrompt(status: .authorized))
            #expect(!WebViewController.needsNotificationPermissionPrompt(status: .denied))
        }
    }

    @Test func staysAwayOnceAnswered() {
        withPromptAnswered(true) {
            #expect(!WebViewController.needsNotificationPermissionPrompt(status: .notDetermined))
        }
    }
}
