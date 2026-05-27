import Intents
import OHHTTPStubs
import PromiseKit
@testable import Shared
import UIKit
import UserNotifications
import XCTest

final class NotificationCommunicationDecoratorTests: XCTestCase {
    private var cache: InMemoryIconCache!
    private var decorator: NotificationCommunicationDecoratorImpl!
    private var api: FakeHomeAssistantAPI!

    override func setUp() {
        super.setUp()
        cache = InMemoryIconCache()
        decorator = NotificationCommunicationDecoratorImpl(cache: cache)
        api = FakeHomeAssistantAPI(server: .fake())
    }

    private func content(title: String = "Dishwasher", body: String = "Cycle complete.") -> UNNotificationContent {
        let c = UNMutableNotificationContent()
        c.title = title
        c.body = body
        return c
    }

    // MARK: - MDI

    func testBuildIntent_mdi_setsSenderNameAndImage() throws {
        let info = NotificationSenderInfo(
            source: .mdi(name: "mdi:door", background: .red, foreground: .white),
            senderName: "Front Door"
        )
        let intent = try hang(Promise(decorator.buildIntent(
            sender: info,
            title: "Front Door",
            body: "Opened",
            api: api
        )))

        XCTAssertEqual(intent.sender?.displayName, "Front Door")
        XCTAssertNotNil(intent.sender?.image, "MDI source must produce a non-nil INImage")
        XCTAssertEqual(intent.content, "Opened")
        XCTAssertEqual(intent.serviceName, "HomeAssistant")
    }

    func testBuildIntent_conversationIdentifier_stableAcrossCalls() throws {
        let info = NotificationSenderInfo(
            source: .mdi(name: "mdi:door", background: .red, foreground: .white),
            senderName: "Front Door"
        )
        let intent1 = try hang(Promise(decorator.buildIntent(sender: info, title: "Front Door", body: "x", api: api)))
        let intent2 = try hang(Promise(decorator.buildIntent(sender: info, title: "Front Door", body: "y", api: api)))
        XCTAssertEqual(intent1.conversationIdentifier, intent2.conversationIdentifier)
        XCTAssertFalse(intent1.conversationIdentifier?.isEmpty ?? true)
    }

    func testBuildIntent_conversationIdentifier_differsForDifferentSenderNames() throws {
        let a = NotificationSenderInfo(
            source: .mdi(name: "mdi:door", background: .red, foreground: .white),
            senderName: "Front Door"
        )
        let b = NotificationSenderInfo(
            source: .mdi(name: "mdi:door", background: .red, foreground: .white),
            senderName: "Back Door"
        )
        let ia = try hang(Promise(decorator.buildIntent(sender: a, title: "Front Door", body: "x", api: api)))
        let ib = try hang(Promise(decorator.buildIntent(sender: b, title: "Back Door", body: "x", api: api)))
        XCTAssertNotEqual(ia.conversationIdentifier, ib.conversationIdentifier)
    }

    func testDecorate_emptyTitle_returnsOriginalContentUnchanged() throws {
        let original = content(title: "", body: "x")
        let info = NotificationSenderInfo(
            source: .mdi(name: "mdi:door", background: .red, foreground: .white),
            senderName: "X" // ignored — decorator uses content.title
        )
        let result = try hang(Promise(decorator.decorate(content: original, sender: info, api: api)))
        XCTAssertEqual(result, original)
    }

    // MARK: - URL

    func testBuildIntent_iconURL_cacheHit_skipsDownload() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/avatar.png"))
        let pngBytes = makeRedPNG() // helper below
        cache.setData(pngBytes, forKey: notificationIconCacheKey(for: url))

        let info = NotificationSenderInfo(
            source: .iconURL(url, needsAuth: false),
            senderName: "Alex"
        )
        let intent = try hang(Promise(decorator.buildIntent(
            sender: info, title: "Alex", body: "Hi", api: api
        )))
        XCTAssertNotNil(intent.sender?.image)
        // Cache hit means no HTTP call should have occurred. We assert that by
        // confirming no stubs are required for this test to pass.
    }

    func testBuildIntent_iconURL_cacheMiss_downloadsThenCaches() throws {
        let url = try XCTUnwrap(URL(string: "https://homeassistant.local:8123/icon.png"))
        let pngBytes = makeRedPNG()

        let stubDesc = HTTPStubs.stubRequests(passingTest: { $0.url == url }) { _ in
            HTTPStubsResponse(data: pngBytes, statusCode: 200, headers: nil)
        }
        defer { HTTPStubs.removeStub(stubDesc) }

        let info = NotificationSenderInfo(
            source: .iconURL(url, needsAuth: false),
            senderName: "Alex"
        )
        let intent = try hang(Promise(decorator.buildIntent(
            sender: info, title: "Alex", body: "Hi", api: api
        )))
        XCTAssertNotNil(intent.sender?.image)
        XCTAssertNotNil(
            cache.data(forKey: notificationIconCacheKey(for: url)),
            "after download, the image must be cached"
        )
    }

    func testBuildIntent_iconURL_downloadFails_returnsIntentWithNilImage() throws {
        let url = try XCTUnwrap(URL(string: "https://homeassistant.local:8123/missing.png"))
        let stubDesc = HTTPStubs.stubRequests(passingTest: { $0.url == url }) { _ in
            HTTPStubsResponse(data: Data(), statusCode: 500, headers: nil)
        }
        defer { HTTPStubs.removeStub(stubDesc) }

        let info = NotificationSenderInfo(
            source: .iconURL(url, needsAuth: false),
            senderName: "Alex"
        )
        let intent = try hang(Promise(decorator.buildIntent(
            sender: info, title: "Alex", body: "Hi", api: api
        )))
        XCTAssertNil(intent.sender?.image, "failed download must produce a nil image, not crash")
        XCTAssertEqual(intent.sender?.displayName, "Alex", "we still build a sender so styling proceeds")
    }

    private func makeRedPNG() -> Data {
        UIGraphicsImageRenderer(size: CGSize(width: 32, height: 32)).pngData { _ in
            UIColor.red.setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: 32, height: 32))
        }
    }
}

// MARK: - Test doubles

private final class InMemoryIconCache: NotificationIconCache {
    var store: [String: Data] = [:]
    func data(forKey key: String) -> Data? { store[key] }
    func setData(_ data: Data, forKey key: String) { store[key] = data }
}

private final class FakeHomeAssistantAPI: HomeAssistantAPI {}
