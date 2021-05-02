import Foundation
import Shared
import UserNotifications
import WatchKit

class DynamicNotificationController: WKUserNotificationInterfaceController {
    @IBOutlet var notificationTitleLabel: WKInterfaceLabel!
    @IBOutlet var notificationSubtitleLabel: WKInterfaceLabel!
    @IBOutlet var notificationAlertLabel: WKInterfaceLabel!

    override func didReceive(_ notification: UNNotification) {
        super.didReceive(notification)

        notificationTitleLabel.setTextAndHideIfEmpty(notification.request.content.title)
        notificationSubtitleLabel.setTextAndHideIfEmpty(notification.request.content.subtitle)
        notificationAlertLabel.setTextAndHideIfEmpty(notification.request.content.body)

        notificationActions = notification.request.content.userInfoActions
    }
}
