import Foundation
import Shared
import SwiftMessages

// MARK: - Post onboarding

extension WebViewController {
    func postOnboardingNotificationPermission() {
        // 3 seconds feels a good timin to show this notification after the user has onboarded
        let delayedSeconds: CGFloat = 3
        DispatchQueue.main.asyncAfter(deadline: .now() + delayedSeconds) { [weak self] in
            Task {
                let notificationCenter = Current.userNotificationCenter
                let settings = await notificationCenter.notificationSettings()
                if ![.authorized, .denied].contains(settings.authorizationStatus) {
                    self?.showNotificationPermissionRequest()
                }
            }
        }
    }

    private func showNotificationPermissionRequest() {
        let view = MessageView.viewFromNib(layout: .cardView)
        var config = SwiftMessages.Config()
        config.duration = .forever
        config.presentationStyle = .top
        config.dimMode = .gray(interactive: true)
        view.configureContent(
            title: L10n.PostOnboarding.Permission.Notification.title,
            body: L10n.PostOnboarding.Permission.Notification.message,
            iconImage: nil,
            iconText: nil,
            buttonImage: MaterialDesignIcons.arrowRightBoldCircleIcon.image(
                ofSize: .init(width: 35, height: 35),
                color: .haPrimary
            ),
            buttonTitle: nil,
            buttonTapHandler: { _ in
                SwiftMessages.hide()
                UNUserNotificationCenter.current().requestAuthorization(options: .defaultOptions) { _, error in
                    if let error {
                        Current.Log.error("Error when requesting notifications permissions: \(error)")
                    }
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
            }
        )
        view.titleLabel?.numberOfLines = 0
        view.bodyLabel?.numberOfLines = 0

        SwiftMessages.show(config: config, view: view)
    }
}
