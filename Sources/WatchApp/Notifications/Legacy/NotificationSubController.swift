import Shared
import UserNotifications

protocol NotificationSubController: AnyObject {
    init?(api: HomeAssistantAPI, notification: UNNotification)
    init?(api: HomeAssistantAPI, url: URL)
    func start() -> DynamicContent
    func stop()
}
