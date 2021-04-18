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

        notificationTitleLabel.setText(notification.request.content.title)
        notificationSubtitleLabel.setText(notification.request.content.subtitle)
        notificationAlertLabel!.setText(notification.request.content.body)

        notificationActions = notification.request.content.userInfoActions
    }
}
