import Foundation
import Shared
import SwiftMessages
import SwiftUI

// MARK: - Post onboarding

extension WebViewController {
    func postOnboardingNotificationPermission() {
        // 3 seconds feels a good timin to show this notification after the user has onboarded
        let delayedSeconds: CGFloat = 3
        DispatchQueue.main.asyncAfter(deadline: .now() + delayedSeconds) { [weak self] in
            Task {
                let settings = await Current.userNotificationCenter.notificationSettings()
                if ![.authorized, .denied].contains(settings.authorizationStatus) {
                    self?.showNotificationPermissionRequest()
                }
            }
        }
    }

    private func showNotificationPermissionRequest() {
        let view = NotificationPermissionRequestView().embeddedInHostingController()
        view.modalPresentationStyle = .overFullScreen
        view.view.backgroundColor = .clear
        view.modalTransitionStyle = .crossDissolve
        present(view, animated: true)
    }
}
