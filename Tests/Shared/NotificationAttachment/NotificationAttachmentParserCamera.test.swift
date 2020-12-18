import Foundation
@testable import Shared
import XCTest
import PromiseKit
import CoreServices

class NotificationAttachmentParserCameraTests: XCTestCase {
    private typealias CameraError = NotificationAttachmentParserCamera.CameraError

    private var parser: NotificationAttachmentParserCamera!

    override func setUp() {
        super.setUp()

        parser = NotificationAttachmentParserCamera()
    }

    func testCameraIdentifiers() {
        let validIdentifiers: [String] = [
            "camera",
            "CAMERA",
            "camera1",
            "CAMERA1",
            "camera2",
            "CAMERA2"
        ]

        let invalidIdentifiers: [String] = [
            "", // same as no category in api
            "cammy",
            "alarm",
            "alert"
        ]

        for valid in validIdentifiers {
            let content = UNMutableNotificationContent()
            content.categoryIdentifier = valid
            let promise = parser.attachmentInfo(from: content)
            XCTAssertNotEqual(promise.wait(), .missing)
        }

        for invalid in invalidIdentifiers {
            let content = UNMutableNotificationContent()
            content.categoryIdentifier = invalid
            let promise = parser.attachmentInfo(from: content)
            XCTAssertEqual(promise.wait(), .missing)
        }
    }

    func testMissingEntityID() {
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = "camera"
        let promise = parser.attachmentInfo(from: content)
        XCTAssertEqual(promise.wait(), .rejected(CameraError.noEntity))
    }

    func testInvalidEntityID() {
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = "camera"
        content.userInfo["entity_id"] = "\\"
        let promise = parser.attachmentInfo(from: content)
        XCTAssertEqual(promise.wait(), .rejected(CameraError.invalidEntity))
    }

    func testAttachmentHidden() {
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = "camera"
        content.userInfo["entity_id"] = "camera.any"
        content.userInfo["attachment"] = [
            "hide-thumbnail": true
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

    func testAttachmentNotHidden() {
        let content = UNMutableNotificationContent()
        content.categoryIdentifier = "camera"
        content.userInfo["entity_id"] = "camera.any"
        content.userInfo["attachment"] = [
            "hide-thumbnail": false
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
        content.categoryIdentifier = "camera"
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
