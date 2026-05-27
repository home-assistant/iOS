@testable import Shared
import UIKit
import UserNotifications
import XCTest

final class NotificationSenderParserTests: XCTestCase {
    private func content(title: String = "Hi", userInfo: [AnyHashable: Any]) -> UNNotificationContent {
        let c = UNMutableNotificationContent()
        c.title = title
        c.userInfo = userInfo
        return c
    }

    /// Asserts that a UIColor resolves to the same values as `AppConstants.tintColor`
    /// in both light and dark trait collections.
    ///
    /// Direct `XCTAssertEqual(color, AppConstants.tintColor)` is unreliable: `tintColor`
    /// is a dynamic `UIColor` built from a closure, and UIColor equality on two
    /// independently-constructed dynamic providers compares closure identity, not
    /// resolved component values. We resolve both sides in each trait collection
    /// and compare those concrete values, which keeps the assertion in sync with
    /// whatever `tintColor`'s provider currently returns.
    private func assertIsTintColor(_ color: UIColor, file: StaticString = #file, line: UInt = #line) {
        let expected = AppConstants.tintColor
        for style in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: style)
            XCTAssertEqual(
                color.resolvedColor(with: traits),
                expected.resolvedColor(with: traits),
                "Expected tint-color-equivalent in style \(style), but got \(color)",
                file: file,
                line: line
            )
        }
    }

    func testNoIconFields_returnsNil() {
        XCTAssertNil(NotificationSenderParser.parse(from: content(userInfo: [:])))
    }

    func testEmptyTitle_returnsNil_evenWithIcon() {
        let c = content(title: "", userInfo: ["notification_icon": "mdi:door"])
        XCTAssertNil(NotificationSenderParser.parse(from: c))
    }

    func testMdiOnly_defaults() {
        let parsed = NotificationSenderParser.parse(from: content(userInfo: [
            "notification_icon": "mdi:door",
        ]))
        guard case let .mdi(name, background, foreground) = parsed?.source else {
            return XCTFail("expected mdi source, got \(String(describing: parsed))")
        }
        XCTAssertEqual(name, "mdi:door")
        assertIsTintColor(background)
        XCTAssertEqual(foreground, .white)
        XCTAssertEqual(parsed?.senderName, "Hi")
    }

    func testMdiWithColor_appliedAsBackground() {
        let parsed = NotificationSenderParser.parse(from: content(userInfo: [
            "notification_icon": "mdi:door",
            "color": "#2196F3",
        ]))
        guard case let .mdi(_, background, _) = parsed?.source else { return XCTFail() }
        XCTAssertEqual(background, UIColor(hex: "#2196F3"))
    }

    func testMdiWithNotificationIconColor_appliedAsForeground() {
        let parsed = NotificationSenderParser.parse(from: content(userInfo: [
            "notification_icon": "mdi:door",
            "notification_icon_color": "#FF5722",
        ]))
        guard case let .mdi(_, _, foreground) = parsed?.source else { return XCTFail() }
        XCTAssertEqual(foreground, UIColor(hex: "#FF5722"))
    }

    func testMdiWithMalformedColor_fallsBackToDefault() {
        let parsed = NotificationSenderParser.parse(from: content(userInfo: [
            "notification_icon": "mdi:door",
            "color": "not-a-color",
        ]))
        guard case let .mdi(_, background, _) = parsed?.source else { return XCTFail() }
        assertIsTintColor(background)
    }

    func testIconURLAbsolute_noAuth() throws {
        let parsed = NotificationSenderParser.parse(from: content(userInfo: [
            "icon_url": "https://example.com/x.png",
        ]))
        guard case let .iconURL(url, needsAuth) = parsed?.source else { return XCTFail() }
        XCTAssertEqual(url, try XCTUnwrap(URL(string: "https://example.com/x.png")))
        XCTAssertFalse(needsAuth)
    }

    func testIconURLRelative_needsAuth() throws {
        let parsed = NotificationSenderParser.parse(from: content(userInfo: [
            "icon_url": "/local/x.png",
        ]))
        guard case let .iconURL(url, needsAuth) = parsed?.source else { return XCTFail() }
        XCTAssertEqual(url, try XCTUnwrap(URL(string: "/local/x.png")))
        XCTAssertTrue(needsAuth)
    }

    func testIconURLInvalidString_returnsNil() {
        let parsed = NotificationSenderParser.parse(from: content(userInfo: [
            "icon_url": "",
        ]))
        XCTAssertNil(parsed)
    }

    func testIconURLWinsOverNotificationIcon() {
        let parsed = NotificationSenderParser.parse(from: content(userInfo: [
            "notification_icon": "mdi:door",
            "icon_url": "https://example.com/x.png",
        ]))
        guard case .iconURL = parsed?.source else {
            return XCTFail("icon_url must take precedence")
        }
    }
}
