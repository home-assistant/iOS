import CoreServices
import Foundation
import PromiseKit
import UserNotifications

final class NotificationAttachmentParserCamera: NotificationAttachmentParser {
    enum CameraError: LocalizedError {
        case invalidEntity

        var errorDescription: String? {
            switch self {
            case .invalidEntity: return L10n.NotificationService.Parser.Camera.invalidEntity
            }
        }
    }

    func attachmentInfo(from content: UNNotificationContent) -> Guarantee<NotificationAttachmentParserResult> {
        guard let entityId = content.userInfo["entity_id"] as? String, entityId.hasPrefix("camera.") else {
            return .value(.missing)
        }

        guard let proxyURL = URL(string: "/api/camera_proxy/\(entityId)") else {
            return .value(.rejected(CameraError.invalidEntity))
        }

        let hideThumbnail = (content.userInfo["attachment"] as? [String: Any])?["hide-thumbnail"] as? Bool
        let lazy = (content.userInfo["attachment"] as? [String: Any])?["lazy"] as? Bool == true

        return .value(.fulfilled(.init(
            url: proxyURL,
            needsAuth: true,
            typeHint: kUTTypeJPEG,
            hideThumbnail: hideThumbnail,
            lazy: lazy
        )))
    }
}
