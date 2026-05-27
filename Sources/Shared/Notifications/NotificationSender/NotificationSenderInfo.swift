import Foundation

// UIKit is available on watchOS (limited subset). UIColor is used in Source.mdi;
// MDI rendering itself is guarded by #if os(iOS) in NotificationCommunicationDecorator.
import UIKit

/// Parsed representation of the icon/sender fields in a push payload that should
/// trigger Communication Notification styling.
public struct NotificationSenderInfo: Equatable {
    public enum Source: Equatable {
        /// User-supplied image URL. `needsAuth` is true when the URL string begins with `/`
        /// (matching the rule in `NotificationAttachmentParserURL`).
        case iconURL(URL, needsAuth: Bool)

        /// Built-in Material Design Icon, rendered onto a colored square.
        /// `background` defaults to `AppConstants.tintColor` when `color` is absent.
        /// `foreground` defaults to `.white` when `notification_icon_color` is absent.
        case mdi(name: String, background: UIColor, foreground: UIColor)
    }

    public let source: Source
    /// The notification's title — used as the sender's display name. Required, non-empty.
    public let senderName: String

    public init(source: Source, senderName: String) {
        self.source = source
        self.senderName = senderName
    }
}
