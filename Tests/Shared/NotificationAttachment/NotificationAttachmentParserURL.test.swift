import CoreServices
import Foundation
@testable import Shared
import XCTest

class NotificationAttachmentParserURLTests: XCTestCase {
    private typealias URLError = NotificationAttachmentParserURL.URLError

    private var parser: NotificationAttachmentParserURL!

    override func setUp() {
        super.setUp()

        parser = NotificationAttachmentParserURL()
    }

    func testNoAttachment() {
        let content = UNMutableNotificationContent()
        let promise = parser.attachmentInfo(from: content)
        XCTAssertEqual(promise.wait(), .missing)
    }

    func testAttachmentNoURL() {
        let content = UNMutableNotificationContent()
        content.userInfo["attachment"] = [String: Any]()
        let promise = parser.attachmentInfo(from: content)
        XCTAssertEqual(promise.wait(), .rejected(URLError.noURL))
    }

    func testInvalidURL() {
        let content = UNMutableNotificationContent()
        content.userInfo["attachment"] = [
            "url": "",
        ]
        let promise = parser.attachmentInfo(from: content)
        XCTAssertEqual(promise.wait(), .rejected(URLError.invalidURL))
    }

    func testRelativeAttachmentURL() {
        let content = UNMutableNotificationContent()
        content.userInfo["attachment"] = [
            "url": "/media/local/file.png",
        ]
        let promise = parser.attachmentInfo(from: content)

        guard let result = promise.wait().attachmentInfo else {
            XCTFail("not an attachment")
            return
        }

        XCTAssertEqual(result.url, URL(string: "/media/local/file.png"))
        XCTAssertEqual(result.needsAuth, true)
        XCTAssertEqual(result.typeHint, nil)
        XCTAssertEqual(result.hideThumbnail, nil)
        XCTAssertEqual(result.lazy, false)
    }

    func testAbsoluteAttachmentURL() {
        let content = UNMutableNotificationContent()
        content.userInfo["attachment"] = [
            "url": "http://google.com/media/local/file.png",
        ]
        let promise = parser.attachmentInfo(from: content)

        guard let result = promise.wait().attachmentInfo else {
            XCTFail("not an attachment")
            return
        }

        XCTAssertEqual(result.url, URL(string: "http://google.com/media/local/file.png"))
        XCTAssertEqual(result.needsAuth, false)
        XCTAssertEqual(result.typeHint, nil)
        XCTAssertEqual(result.hideThumbnail, nil)
        XCTAssertEqual(result.lazy, false)
    }

    func testContentType() {
        let content = UNMutableNotificationContent()
        content.userInfo["attachment"] = [
            "url": "/media/local/file.png",
            "content-type": "png",
        ]
        let promise = parser.attachmentInfo(from: content)

        guard let result = promise.wait().attachmentInfo else {
            XCTFail("not an attachment")
            return
        }

        XCTAssertEqual(result.url, URL(string: "/media/local/file.png"))
        XCTAssertEqual(result.needsAuth, true)
        XCTAssertEqual(result.typeHint, kUTTypePNG)
        XCTAssertEqual(result.hideThumbnail, nil)
        XCTAssertEqual(result.lazy, false)
    }

    func testAttachmentHidden() {
        let content = UNMutableNotificationContent()
        content.userInfo["attachment"] = [
            "url": "/media/local/file.png",
            "hide-thumbnail": true,
        ]
        let promise = parser.attachmentInfo(from: content)

        guard let result = promise.wait().attachmentInfo else {
            XCTFail("not an attachment")
            return
        }

        XCTAssertEqual(result.url, URL(string: "/media/local/file.png"))
        XCTAssertEqual(result.needsAuth, true)
        XCTAssertEqual(result.typeHint, nil)
        XCTAssertEqual(result.hideThumbnail, true)
        XCTAssertEqual(result.lazy, false)
    }

    func testAttachmentNotHidden() {
        let content = UNMutableNotificationContent()
        content.userInfo["attachment"] = [
            "url": "/media/local/file.png",
            "hide-thumbnail": false,
        ]
        let promise = parser.attachmentInfo(from: content)

        guard let result = promise.wait().attachmentInfo else {
            XCTFail("not an attachment")
            return
        }

        XCTAssertEqual(result.url, URL(string: "/media/local/file.png"))
        XCTAssertEqual(result.needsAuth, true)
        XCTAssertEqual(result.typeHint, nil)
        XCTAssertEqual(result.hideThumbnail, false)
        XCTAssertEqual(result.lazy, false)
    }

    func testLazyTrue() {
        let content = UNMutableNotificationContent()
        content.userInfo["attachment"] = [
            "url": "/media/local/file.png",
            "lazy": true,
        ]
        let promise = parser.attachmentInfo(from: content)

        guard let result = promise.wait().attachmentInfo else {
            XCTFail("not an attachment")
            return
        }

        XCTAssertEqual(result.url, URL(string: "/media/local/file.png"))
        XCTAssertEqual(result.needsAuth, true)
        XCTAssertEqual(result.typeHint, nil)
        XCTAssertEqual(result.hideThumbnail, nil)
        XCTAssertEqual(result.lazy, true)
    }

    func testLazyFalse() {
        let content = UNMutableNotificationContent()
        content.userInfo["attachment"] = [
            "url": "/media/local/file.png",
            "lazy": false,
        ]
        let promise = parser.attachmentInfo(from: content)

        guard let result = promise.wait().attachmentInfo else {
            XCTFail("not an attachment")
            return
        }

        XCTAssertEqual(result.url, URL(string: "/media/local/file.png"))
        XCTAssertEqual(result.needsAuth, true)
        XCTAssertEqual(result.typeHint, nil)
        XCTAssertEqual(result.hideThumbnail, nil)
        XCTAssertEqual(result.lazy, false)
    }
}
