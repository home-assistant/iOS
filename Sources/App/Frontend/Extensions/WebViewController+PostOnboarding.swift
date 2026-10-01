import Foundation
import Shared
import SwiftUI
import UserNotifications

// MARK: - Post onboarding

extension WebViewController {
    func postOnboardingNotificationPermission() {
        // 3 seconds feels a good timin to show this notification after the user has onboarded
        let delayedSeconds: CGFloat = 3
        DispatchQueue.main.asyncAfter(deadline: .now() + delayedSeconds) { [weak self] in
            Task {
                let settings = await Current.userNotificationCenter.notificationSettings()
                if Self.needsNotificationPermissionPrompt(status: settings.authorizationStatus) {
                    self?.showNotificationPermissionRequest()
                }
            }
        }
    }

    /// Whether the app's own prompt is still owed: the system has not decided and the prompt was never answered.
    static func needsNotificationPermissionPrompt(status: UNAuthorizationStatus) -> Bool {
        guard !Current.settingsStore.notificationPermissionPromptAnswered else { return false }
        return ![.authorized, .denied].contains(status)
    }

    private func showNotificationPermissionRequest() {
        let view = NotificationPermissionRequestView().embeddedInHostingController()
        view.presentsAsTransparentOverlay()
        present(view, animated: true)
    }
}
