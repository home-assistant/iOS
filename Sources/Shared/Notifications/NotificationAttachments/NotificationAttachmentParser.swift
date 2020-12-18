import Foundation
import PromiseKit
import UserNotifications
import CoreServices

internal protocol NotificationAttachmentParser {
    init()
    func attachmentInfo(from content: UNNotificationContent) -> Guarantee<NotificationAttachmentParserResult>
}

internal enum NotificationAttachmentParserResult: Equatable {
    case fulfilled(NotificationAttachmentInfo)
    case missing
    case rejected(Error)

    var attachmentInfo: NotificationAttachmentInfo? {
        switch self {
        case .fulfilled(let info): return info
        case .missing, .rejected: return nil
        }
    }

    var error: Error? {
        switch self {
        case .rejected(let error): return error
        case .missing, .fulfilled: return nil
        }
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.missing, .missing):
            return true
        case (.fulfilled(let lhsValue), .fulfilled(let rhsValue)):
            return lhsValue == rhsValue
        case (.rejected(let lhsError as NSError), .rejected(let rhsError as NSError)):
            return lhsError.domain == rhsError.domain &&
                lhsError.code == rhsError.code
        default:
            return false
        }
    }
}

internal struct NotificationAttachmentInfo: Equatable {
    var url: URL
    var needsAuth: Bool
    var typeHint: CFString?
    var hideThumbnail: Bool?

    var attachmentOptions: [String: Any] {
        var options = [String: Any]()

        if let typeHint = typeHint {
            options[UNNotificationAttachmentOptionsTypeHintKey] = typeHint
        }

        if let hideThumbnail = hideThumbnail {
            options[UNNotificationAttachmentOptionsThumbnailHiddenKey] = hideThumbnail
        }

        return options
    }

    // swiftlint:disable:next cyclomatic_complexity
    static func contentType(for contentTypeString: String) -> CFString {
        let contentType: CFString
        switch contentTypeString.lowercased() {
        case "aiff":
            contentType = kUTTypeAudioInterchangeFileFormat
        case "avi":
            contentType = kUTTypeAVIMovie
        case "gif":
            contentType = kUTTypeGIF
        case "jpeg", "jpg":
            contentType = kUTTypeJPEG
        case "mp3":
            contentType = kUTTypeMP3
        case "mpeg":
            contentType = kUTTypeMPEG
        case "mpeg2":
            contentType = kUTTypeMPEG2Video
        case "mpeg4":
            contentType = kUTTypeMPEG4
        case "mpeg4audio":
            contentType = kUTTypeMPEG4Audio
        case "png":
            contentType = kUTTypePNG
        case "waveformaudio":
            contentType = kUTTypeWaveformAudio
        default:
            contentType = contentTypeString as CFString
        }

        return contentType
    }
}
