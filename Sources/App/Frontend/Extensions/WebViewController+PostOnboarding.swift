import Foundation
import Shared
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

    /// A system sheet fixed to the medium detent, so it stays clear of the bottom safe area the way
    /// any other sheet does, and its content spans the full width on iPhone Duo.
    func showNotificationPermissionRequest() {
        let controller = NotificationPermissionRequestView().embeddedInHostingController()

        if Current.isCatalyst {
            controller.modalPresentationStyle = .formSheet
        } else if let sheet = controller.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
        }
        present(controller, animated: true)
    }
}
