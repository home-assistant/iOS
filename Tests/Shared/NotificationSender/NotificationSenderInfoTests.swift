@testable import Shared
import UIKit
import XCTest

final class NotificationSenderInfoTests: XCTestCase {
    func testEquatable_sameValues_areEqual() {
        let a = NotificationSenderInfo(
            source: .mdi(name: "mdi:door", background: .red, foreground: .white),
            senderName: "Front Door"
        )
        let b = NotificationSenderInfo(
            source: .mdi(name: "mdi:door", background: .red, foreground: .white),
            senderName: "Front Door"
        )
        XCTAssertEqual(a, b)
    }

    func testEquatable_differentSenderName_areNotEqual() {
        let a = NotificationSenderInfo(
            source: .mdi(name: "mdi:door", background: .red, foreground: .white),
            senderName: "Front Door"
        )
        let b = NotificationSenderInfo(
            source: .mdi(name: "mdi:door", background: .red, foreground: .white),
            senderName: "Back Door"
        )
        XCTAssertNotEqual(a, b)
    }

    func testEquatable_iconURLNeedsAuthDiffers_areNotEqual() throws {
        let url = try XCTUnwrap(URL(string: "/local/x.png"))
        let a = NotificationSenderInfo(source: .iconURL(url, needsAuth: true), senderName: "X")
        let b = NotificationSenderInfo(source: .iconURL(url, needsAuth: false), senderName: "X")
        XCTAssertNotEqual(a, b)
    }
}
