import Foundation
import SharedPush
import UIKit
import UserNotifications

public enum NotificationSenderParser {
    public static func parse(from content: UNNotificationContent) -> NotificationSenderInfo? {
        // Communication notifications display the sender name in place of the title,
        // so fall back to the app name for notifications sent without one.
        let senderName = content.title.isEmpty ? "Home Assistant" : content.title

        let userInfo = content.userInfo
        let nestedData = userInfo["data"] as? [String: Any]

        func value(forKey key: String) -> Any? {
            userInfo[key] ?? nestedData?[key]
        }

        if let urlString = value(forKey: NotificationPayloadKey.iconURL.rawValue) as? String,
           !urlString.isEmpty,
           let url = URL(string: urlString) {
            return NotificationSenderInfo(
                source: .iconURL(url, needsAuth: urlString.hasPrefix("/")),
                senderName: senderName
            )
        }

        if let mdiName = value(forKey: NotificationPayloadKey.notificationIcon.rawValue) as? String,
           !mdiName.isEmpty {
            let colorString = value(forKey: NotificationPayloadKey.color.rawValue) as? String
            let iconColorString = value(forKey: NotificationPayloadKey.notificationIconColor.rawValue) as? String
            let background = colorString.flatMap(Self.color(fromHex:))
                ?? AppConstants.tintColor
            let foreground = iconColorString.flatMap(Self.color(fromHex:))
                ?? .white
            return NotificationSenderInfo(
                source: .mdi(
                    name: mdiName,
                    background: background,
                    foreground: foreground,
                    colorString: colorString,
                    iconColorString: iconColorString
                ),
                senderName: senderName
            )
        }

        return nil
    }

    private static func color(fromHex hex: String) -> UIColor? {
        UIColor(rgbaString: hex)
    }
}
