import Foundation
@testable import Shared
import UniformTypeIdentifiers
import UserNotifications
import XCTest

final class NotificationAttachmentInfoTests: XCTestCase {
    private enum TestError: Error {
        case first
        case second
    }

    private func info(
        url: String = "https://example.com/a.png",
        typeHint: CFString? = nil,
        hideThumbnail: Bool? = nil
    ) -> NotificationAttachmentInfo {
        NotificationAttachmentInfo(
            url: URL(string: url)!,
            needsAuth: false,
            typeHint: typeHint,
            hideThumbnail: hideThumbnail,
            lazy: false
        )
    }

    func testContentTypeMapsKnownNamesCaseInsensitively() {
        let expected: [String: UTType] = [
            "aiff": .aiff,
            "avi": .avi,
            "gif": .gif,
            "jpeg": .jpeg,
            "JPG": .jpeg,
            "mp3": .mp3,
            "mpeg": .mpeg,
            "mpeg2": .mpeg2Video,
            "mpeg4": .mpeg4Movie,
            "mpeg4audio": .mpeg4Audio,
            "PNG": .png,
            "waveformaudio": .wav,
        ]

        for (name, type) in expected {
            XCTAssertEqual(
                NotificationAttachmentInfo.contentType(for: name) as String,
                type.identifier,
                "content type for \(name)"
            )
        }
    }

    func testContentTypePassesThroughUnknownNames() {
        XCTAssertEqual(NotificationAttachmentInfo.contentType(for: "public.heic") as String, "public.heic")
    }

    func testAttachmentOptionsAreEmptyWithoutHints() {
        XCTAssertTrue(info().attachmentOptions.isEmpty)
    }

    func testAttachmentOptionsIncludeTypeHintAndThumbnail() {
        let options = info(typeHint: UTType.png.identifier as CFString, hideThumbnail: true).attachmentOptions

        XCTAssertEqual(options.count, 2)
        XCTAssertEqual(options[UNNotificationAttachmentOptionsTypeHintKey] as? String, UTType.png.identifier)
        XCTAssertEqual(options[UNNotificationAttachmentOptionsThumbnailHiddenKey] as? Bool, true)
    }

    func testResultAccessors() {
        let fulfilled = NotificationAttachmentParserResult.fulfilled(info())
        XCTAssertEqual(fulfilled.attachmentInfo, info())
        XCTAssertNil(fulfilled.error)

        let missing = NotificationAttachmentParserResult.missing
        XCTAssertNil(missing.attachmentInfo)
        XCTAssertNil(missing.error)

        let rejected = NotificationAttachmentParserResult.rejected(TestError.first)
        XCTAssertNil(rejected.attachmentInfo)
        XCTAssertTrue(rejected.error is TestError)
    }

    func testResultEquality() {
        XCTAssertEqual(NotificationAttachmentParserResult.missing, .missing)
        XCTAssertEqual(NotificationAttachmentParserResult.fulfilled(info()), .fulfilled(info()))
        XCTAssertNotEqual(
            NotificationAttachmentParserResult.fulfilled(info()),
            .fulfilled(info(url: "https://example.com/b.png"))
        )
        XCTAssertEqual(
            NotificationAttachmentParserResult.rejected(TestError.first),
            .rejected(TestError.first)
        )
        XCTAssertNotEqual(
            NotificationAttachmentParserResult.rejected(TestError.first),
            .rejected(TestError.second)
        )
        XCTAssertNotEqual(NotificationAttachmentParserResult.missing, .fulfilled(info()))
        XCTAssertNotEqual(NotificationAttachmentParserResult.missing, .rejected(TestError.first))
    }
}
