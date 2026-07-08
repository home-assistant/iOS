import Foundation
import PromiseKit
import UniformTypeIdentifiers
import UserNotifications

protocol NotificationAttachmentParser {
    init()
    func attachmentInfo(from content: UNNotificationContent) -> Guarantee<NotificationAttachmentParserResult>
}

enum NotificationAttachmentParserResult: Equatable {
    case fulfilled(NotificationAttachmentInfo)
    case missing
    case rejected(Error)

    var attachmentInfo: NotificationAttachmentInfo? {
        switch self {
        case let .fulfilled(info): return info
        case .missing, .rejected: return nil
        }
    }

    var error: Error? {
        switch self {
        case let .rejected(error): return error
        case .missing, .fulfilled: return nil
        }
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.missing, .missing):
            return true
        case let (.fulfilled(lhsValue), .fulfilled(rhsValue)):
            return lhsValue == rhsValue
        case let (.rejected(lhsError as NSError), .rejected(rhsError as NSError)):
            return lhsError.domain == rhsError.domain &&
                lhsError.code == rhsError.code
        default:
            return false
        }
    }
}

struct NotificationAttachmentInfo: Equatable {
    var url: URL
    var needsAuth: Bool
    var typeHint: CFString?
    var hideThumbnail: Bool?
    var lazy: Bool

    var attachmentOptions: [String: Any] {
        var options = [String: Any]()

        if let typeHint {
            options[UNNotificationAttachmentOptionsTypeHintKey] = typeHint
        }

        if let hideThumbnail {
            options[UNNotificationAttachmentOptionsThumbnailHiddenKey] = hideThumbnail
        }

        return options
    }

    static func contentType(for contentTypeString: String) -> CFString {
        let contentType: UTType?
        switch contentTypeString.lowercased() {
        case "aiff":
            contentType = .aiff
        case "avi":
            contentType = .avi
        case "gif":
            contentType = .gif
        case "jpeg", "jpg":
            contentType = .jpeg
        case "mp3":
            contentType = .mp3
        case "mpeg":
            contentType = .mpeg
        case "mpeg2":
            contentType = .mpeg2Video
        case "mpeg4":
            contentType = .mpeg4Movie
        case "mpeg4audio":
            contentType = .mpeg4Audio
        case "png":
            contentType = .png
        case "waveformaudio":
            contentType = .wav
        default:
            contentType = nil
        }

        return (contentType?.identifier ?? contentTypeString) as CFString
    }
}
