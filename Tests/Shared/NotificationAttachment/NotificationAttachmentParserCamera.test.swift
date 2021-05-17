import CoreServices
import Foundation
import PromiseKit
@testable import Shared
import XCTest

class NotificationAttachmentParserCameraTests: XCTestCase {
    private typealias CameraError = NotificationAttachmentParserCamera.CameraError

    private var parser: NotificationAttachmentParserCamera!

    override func setUp() {
        super.setUp()

        parser = NotificationAttachmentParserCamera()
    }

    func testMissingEntityID() {
        let content = UNMutableNotificationContent()
        let promise = parser.attachmentInfo(from: content)
        XCTAssertEqual(promise.wait(), .missing)
    }

    func testInvalidEntityID() {
        let content = UNMutableNotificationContent()
        content.userInfo["entity_id"] = "\\"
        let promise = parser.attachmentInfo(from: content)
        XCTAssertEqual(promise.wait(), .missing)
    }

    func testNonCameraEntityID() {
        let content = UNMutableNotificationContent()
        content.userInfo["entity_id"] = "light.bedroom"
        let promise = parser.attachmentInfo(from: content)
        XCTAssertEqual(promise.wait(), .missing)
    }

    func testAttachmentHidden() {
        let content = UNMutableNotificationContent()
        content.userInfo["entity_id"] = "camera.any"
        content.userInfo["attachment"] = [
            "hide-thumbnail": true,
        ]
        let promise = parser.attachmentInfo(from: content)

        guard let result = promise.wait().attachmentInfo else {
            XCTFail("not an attachment")
            return
        }

        XCTAssertEqual(result.url, URL(string: "/api/camera_proxy/camera.any"))
        XCTAssertEqual(result.needsAuth, true)
        XCTAssertEqual(result.typeHint, kUTTypeJPEG)
        XCTAssertEqual(result.hideThumbnail, true)
    }

    func testAttachmentLazy() {
        let content = UNMutableNotificationContent()
        content.userInfo["entity_id"] = "camera.any"
        content.userInfo["attachment"] = [
            "lazy": true,
        ]
        let promise = parser.attachmentInfo(from: content)

        guard let result = promise.wait().attachmentInfo else {
            XCTFail("not an attachment")
            return
        }

        XCTAssertEqual(result.url, URL(string: "/api/camera_proxy/camera.any"))
        XCTAssertEqual(result.needsAuth, true)
        XCTAssertEqual(result.typeHint, kUTTypeJPEG)
        XCTAssertEqual(result.hideThumbnail, nil)
        XCTAssertEqual(result.lazy, true)
    }

    func testAttachmentNotHidden() {
        let content = UNMutableNotificationContent()
        content.userInfo["entity_id"] = "camera.any"
        content.userInfo["attachment"] = [
            "hide-thumbnail": false,
        ]
        let promise = parser.attachmentInfo(from: content)

        guard let result = promise.wait().attachmentInfo else {
            XCTFail("not an attachment")
            return
        }

        XCTAssertEqual(result.url, URL(string: "/api/camera_proxy/camera.any"))
        XCTAssertEqual(result.needsAuth, true)
        XCTAssertEqual(result.typeHint, kUTTypeJPEG)
        XCTAssertEqual(result.hideThumbnail, false)
    }

    func testAttachmentInfo() {
        let content = UNMutableNotificationContent()
        content.userInfo["entity_id"] = "camera.any"
        let promise = parser.attachmentInfo(from: content)

        guard let result = promise.wait().attachmentInfo else {
            XCTFail("not an attachment")
            return
        }

        XCTAssertEqual(result.url, URL(string: "/api/camera_proxy/camera.any"))
        XCTAssertEqual(result.needsAuth, true)
        XCTAssertEqual(result.typeHint, kUTTypeJPEG)
        XCTAssertEqual(result.hideThumbnail, nil)
    }
}
