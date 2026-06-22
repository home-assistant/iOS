import Foundation
import UIColor_Hex_Swift
import UIKit
import UserNotifications

public enum NotificationSenderParser {
    public static func parse(from content: UNNotificationContent) -> NotificationSenderInfo? {
        let senderName = content.title
        guard !senderName.isEmpty else { return nil }

        let userInfo = content.userInfo
        let nestedData = userInfo["data"] as? [String: Any]

        func value(forKey key: String) -> Any? {
            userInfo[key] ?? nestedData?[key]
        }

        // icon_url wins when both are present.
        if let urlString = value(forKey: "icon_url") as? String,
           !urlString.isEmpty,
           let url = URL(string: urlString) {
            return NotificationSenderInfo(
                source: .iconURL(url, needsAuth: urlString.hasPrefix("/")),
                senderName: senderName
            )
        }

        if let mdiName = value(forKey: "notification_icon") as? String, !mdiName.isEmpty {
            let colorString = value(forKey: "color") as? String
            let iconColorString = value(forKey: "notification_icon_color") as? String
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

    /// Returns nil for malformed inputs so the caller can fall back to a default,
    /// instead of relying on UIColor(hex:)'s crash-on-bad-input behavior.
    private static func color(fromHex hex: String) -> UIColor? {
        guard let color = try? UIColor(rgba_throws: hex) else { return nil }
        return color
    }
}
