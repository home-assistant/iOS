import Foundation
import PromiseKit
import UserNotifications

final class NotificationAttachmentParserURL: NotificationAttachmentParser {
    enum URLError: LocalizedError {
        case noURL
        case invalidURL

        var errorDescription: String? {
            switch self {
            case .noURL: return L10n.NotificationService.Parser.Url.noUrl
            case .invalidURL: return L10n.NotificationService.Parser.Url.invalidUrl
            }
        }
    }

    func attachmentInfo(from content: UNNotificationContent) -> Guarantee<NotificationAttachmentParserResult> {
        guard let attachment = content.userInfo["attachment"] as? [String: Any] else {
            return .value(.missing)
        }

        guard let urlString = attachment["url"] as? String else {
            return .value(.rejected(URLError.noURL))
        }

        guard let url = URL(string: urlString) else {
            return .value(.rejected(URLError.invalidURL))
        }

        let needsAuth: Bool = urlString.hasPrefix("/")
        let contentType = (attachment["content-type"] as? String).flatMap(NotificationAttachmentInfo.contentType(for:))
        let hideThumbnail = attachment["hide-thumbnail"] as? Bool
        let lazy = attachment["lazy"] as? Bool == true

        return .value(.fulfilled(.init(
            url: url,
            needsAuth: needsAuth,
            typeHint: contentType,
            hideThumbnail: hideThumbnail,
            lazy: lazy
        )))
    }
}
