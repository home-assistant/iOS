import Intents
import OHHTTPStubs
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
        decorator = NotificationCommunicationDecoratorImpl(cache: cache) { _, _, _ in
            INImage(imageData: Data([0]))
        }
        api = FakeHomeAssistantAPI(server: .fake())
    }

    override func tearDown() {
        HTTPStubs.removeAllStubs()
        super.tearDown()
    }

    private func content(title: String = "Dishwasher", body: String = "Cycle complete.") -> UNNotificationContent {
        let c = UNMutableNotificationContent()
        c.title = title
        c.body = body
        return c
    }

    func testBuildIntent_mdi_setsSenderNameAndImage() async {
        let info = NotificationSenderInfo(
            source: .mdi(
                name: "mdi:door",
                background: .red,
                foreground: .white,
                colorString: "#FF0000",
                iconColorString: "#FFFFFF"
            ),
            senderName: "Front Door"
        )
        let intent = await decorator.buildIntent(
            sender: info,
            title: "Front Door",
            body: "Opened",
            api: api
        )

        XCTAssertEqual(intent.sender?.displayName, "Front Door")
        XCTAssertNotNil(intent.sender?.image, "MDI source must produce a non-nil INImage")
        XCTAssertEqual(intent.content, "Opened")
        XCTAssertEqual(intent.serviceName, "HomeAssistant")
    }

    func testBuildIntent_conversationIdentifier_stableAcrossCalls() async {
        let info = NotificationSenderInfo(
            source: .mdi(
                name: "mdi:door",
                background: .red,
                foreground: .white,
                colorString: "#FF0000",
                iconColorString: "#FFFFFF"
            ),
            senderName: "Front Door"
        )
        let intent1 = await decorator.buildIntent(sender: info, title: "Front Door", body: "x", api: api)
        let intent2 = await decorator.buildIntent(sender: info, title: "Front Door", body: "y", api: api)
        XCTAssertEqual(intent1.conversationIdentifier, intent2.conversationIdentifier)
        XCTAssertFalse(intent1.conversationIdentifier?.isEmpty ?? true)
    }

    func testBuildIntent_conversationIdentifier_differsForDifferentSenderNames() async {
        let a = NotificationSenderInfo(
            source: .mdi(
                name: "mdi:door",
                background: .red,
                foreground: .white,
                colorString: "#FF0000",
                iconColorString: "#FFFFFF"
            ),
            senderName: "Front Door"
        )
        let b = NotificationSenderInfo(
            source: .mdi(
                name: "mdi:door",
                background: .red,
                foreground: .white,
                colorString: "#FF0000",
                iconColorString: "#FFFFFF"
            ),
            senderName: "Back Door"
        )
        let ia = await decorator.buildIntent(sender: a, title: "Front Door", body: "x", api: api)
        let ib = await decorator.buildIntent(sender: b, title: "Back Door", body: "x", api: api)
        XCTAssertNotEqual(ia.conversationIdentifier, ib.conversationIdentifier)
    }

    func testDecorate_emptyTitle_stillDecorates() async {
        let original = content(title: "", body: "x")
        let info = NotificationSenderInfo(
            source: .mdi(
                name: "mdi:door",
                background: .red,
                foreground: .white,
                colorString: "#FF0000",
                iconColorString: "#FFFFFF"
            ),
            senderName: "Home Assistant"
        )
        let result = await decorator.decorate(content: original, sender: info, api: api)
        XCTAssertFalse(
            result === original,
            "a notification without a title must still be decorated with the sender intent"
        )
    }

    func testBuildIntent_iconURL_cacheHit_skipsDownload() async throws {
        let url = try XCTUnwrap(URL(string: "https://example.com/avatar.png"))
        let pngBytes = makeRedPNG()
        cache.setData(pngBytes, forKey: notificationIconCacheKey(for: url, serverID: api.server.identifier.rawValue))
        let stubDesc = HTTPStubs.stubRequests(passingTest: { $0.url == url }) { _ in
            XCTFail("A cached notification icon must not be downloaded")
            return HTTPStubsResponse(error: URLError(.resourceUnavailable))
        }
        defer { HTTPStubs.removeStub(stubDesc) }

        let info = NotificationSenderInfo(
            source: .iconURL(url, needsAuth: false),
            senderName: "Alex"
        )
        let intent = await decorator.buildIntent(
            sender: info, title: "Alex", body: "Hi", api: api
        )
        XCTAssertNotNil(intent.sender?.image)
    }

    func testBuildIntent_iconURL_cacheMiss_downloadsThenCaches() async throws {
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
        let intent = await decorator.buildIntent(
            sender: info, title: "Alex", body: "Hi", api: api
        )
        XCTAssertNotNil(intent.sender?.image)
        XCTAssertNotNil(
            cache.data(forKey: notificationIconCacheKey(for: url, serverID: api.server.identifier.rawValue)),
            "after download, the image must be cached"
        )
    }

    func testBuildIntent_iconURL_downloadFails_returnsIntentWithNilImage() async throws {
        let url = try XCTUnwrap(URL(string: "https://homeassistant.local:8123/missing.png"))
        let stubDesc = HTTPStubs.stubRequests(passingTest: { $0.url == url }) { _ in
            HTTPStubsResponse(data: Data(), statusCode: 500, headers: nil)
        }
        defer { HTTPStubs.removeStub(stubDesc) }

        let info = NotificationSenderInfo(
            source: .iconURL(url, needsAuth: false),
            senderName: "Alex"
        )
        let intent = await decorator.buildIntent(
            sender: info, title: "Alex", body: "Hi", api: api
        )
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

private final class InMemoryIconCache: NotificationIconCache {
    var store: [String: Data] = [:]
    func data(forKey key: String) -> Data? { store[key] }
    func setData(_ data: Data, forKey key: String) { store[key] = data }
}

private final class FakeHomeAssistantAPI: HomeAssistantAPI {}
