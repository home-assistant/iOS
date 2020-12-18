import Foundation
import UserNotifications
import PromiseKit
import CoreServices

final class NotificationAttachmentParserCamera: NotificationAttachmentParser {
    enum CameraError: LocalizedError {
        case noEntity
        case invalidEntity

        var errorDescription: String? {
            switch self {
            case .noEntity: return L10n.NotificationService.Parser.Camera.noEntity
            case .invalidEntity: return L10n.NotificationService.Parser.Camera.invalidEntity
            }
        }
    }

    func attachmentInfo(from content: UNNotificationContent) -> Guarantee<NotificationAttachmentParserResult> {
        guard content.categoryIdentifier.lowercased().hasPrefix("camera") else {
            return .value(.missing)
        }

        guard let entityId = content.userInfo["entity_id"] as? String else {
            return .value(.rejected(CameraError.noEntity))
        }

        guard let proxyURL = URL(string: "/api/camera_proxy/\(entityId)") else {
            return .value(.rejected(CameraError.invalidEntity))
        }

        let hideThumbnail = (content.userInfo["attachment"] as? [String: Any])?["hide-thumbnail"] as? Bool

        return .value(.fulfilled(.init(
            url: proxyURL,
            needsAuth: true,
            typeHint: kUTTypeJPEG,
            hideThumbnail: hideThumbnail
        )))
    }
}
