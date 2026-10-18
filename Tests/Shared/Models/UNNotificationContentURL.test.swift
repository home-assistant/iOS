import Foundation
@testable import Shared
import UserNotifications
import XCTest

/// The URL a notification asks the app to open, which decides both what a tap does and what an action
/// picked from it does.
final class UNNotificationContentURLTests: XCTestCase {
    private func content(_ userInfo: [String: Any]) -> UNNotificationContent {
        let content = UNMutableNotificationContent()
        content.userInfo = userInfo
        return content
    }

    private func tapURL(_ content: UNNotificationContent) -> String? {
        content.urlString(forActionIdentifier: UNNotificationDefaultActionIdentifier)
    }

    func testNoURLAnywhereMeansNoURL() {
        XCTAssertNil(tapURL(content([:])))
        XCTAssertNil(content([:]).urlString(forActionIdentifier: "OPEN"))
    }

    func testGlobalURLAppliesToTapsAndActionsAlike() {
        let content = content(["url": "/lovelace/dashboard"])

        XCTAssertEqual(tapURL(content), "/lovelace/dashboard")
        XCTAssertEqual(content.urlString(forActionIdentifier: "OPEN"), "/lovelace/dashboard")
    }

    func testReadsTheOtherSpellingsOfAGlobalURL() {
        XCTAssertEqual(tapURL(content(["uri": "/from-uri"])), "/from-uri")
        XCTAssertEqual(tapURL(content(["clickAction": "/from-click-action"])), "/from-click-action")
    }

    func testAnActionsOwnURLOverridesTheGlobalOne() {
        let content = content([
            "url": "/global",
            "actions": [["identifier": "OPEN", "title": "Open", "url": "/per-action"]],
        ])

        XCTAssertEqual(content.urlString(forActionIdentifier: "OPEN"), "/per-action")
        XCTAssertEqual(tapURL(content), "/global")
    }

    func testOldStyleDictionaryIsLookedUpByActionIdentifier() {
        let content = content(["url": ["_": "/fallback", "open": "/open"]])

        XCTAssertEqual(tapURL(content), "/fallback")
        XCTAssertEqual(content.urlString(forActionIdentifier: "OPEN"), "/open")
        XCTAssertNil(content.urlString(forActionIdentifier: "CLOSE"))
    }

    /// What the actions alert leans on: per-action URLs with nothing listed for a plain tap leave the
    /// tap itself with nothing to do.
    func testOldStyleDictionaryWithoutAFallbackLeavesATapWithNoURL() {
        XCTAssertNil(tapURL(content(["url": ["open": "/open"]])))
    }
}
