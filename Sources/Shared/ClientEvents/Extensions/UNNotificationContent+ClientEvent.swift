import Foundation
import UserNotifications

public extension UNNotificationContent {
    var clientEventTitle: String {
        var eventText = ""
        if !title.isEmpty {
            eventText = "\(title)"
            if !subtitle.isEmpty {
                eventText += " - \(subtitle)"
            }
        } else if let message = (userInfo["aps"] as? [String: Any])?["alert"] as? String {
            eventText = message
        }

        return L10n.ClientEvents.EventType.Notification.title(eventText)
    }
}
