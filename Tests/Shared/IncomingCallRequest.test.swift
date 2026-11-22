@testable import Shared
import XCTest

final class IncomingCallRequestTests: XCTestCase {
    private let serverURLs = [
        URL(string: "http://homeassistant.local:8123")!,
        URL(string: "https://example.ui.nabu.casa")!,
    ]

    private func parse(_ fields: [String: Any]) -> Result<IncomingCallRequest, IncomingCallRequest.ParseError> {
        IncomingCallRequest.parse(
            homeassistant: ["command": "incoming_call"].merging(fields, uniquingKeysWith: { _, new in new }),
            serverURLs: serverURLs
        )
    }

    private func request(_ fields: [String: Any]) throws -> IncomingCallRequest {
        try parse(fields).get()
    }

    // MARK: - Command and tag

    func testOtherCommandIsNotACall() {
        XCTAssertEqual(
            IncomingCallRequest.parse(homeassistant: ["command": "clear_notification", "tag": "a"]),
            .failure(.notIncomingCall)
        )
        XCTAssertEqual(IncomingCallRequest.parse(homeassistant: ["tag": "a"]), .failure(.notIncomingCall))
    }

    func testTagIsRequiredAndChecked() {
        XCTAssertEqual(parse([:]), .failure(.invalidTag))
        XCTAssertEqual(parse(["tag": ""]), .failure(.invalidTag))
        XCTAssertEqual(parse(["tag": 12]), .failure(.invalidTag))
        XCTAssertEqual(parse(["tag": "has space"]), .failure(.invalidTag))
        XCTAssertEqual(parse(["tag": "../escape"]), .failure(.invalidTag))
        XCTAssertEqual(parse(["tag": "émoji"]), .failure(.invalidTag))
        XCTAssertEqual(parse(["tag": String(repeating: "a", count: 65)]), .failure(.invalidTag))
        XCTAssertNoThrow(try request(["tag": String(repeating: "a", count: 64)]))
        XCTAssertNoThrow(try request(["tag": "visio-Paris_01"]))
    }

    // MARK: - Caller

    func testCallerIsSanitized() throws {
        XCTAssertEqual(try request(["tag": "a", "caller": "Papa"]).caller, "Papa")
        XCTAssertEqual(try request(["tag": "a", "caller": "  Papa \n\t Maman  "]).caller, "Papa Maman")
        XCTAssertEqual(try request(["tag": "a", "caller": "Pa\u{0}pa\u{7}"]).caller, "Papa")
        XCTAssertEqual(try request(["tag": "a", "caller": "Papa\u{2028}Maman"]).caller, "PapaMaman")
        XCTAssertNil(try request(["tag": "a", "caller": " \n "]).caller)
        XCTAssertNil(try request(["tag": "a", "caller": 42]).caller)
        XCTAssertEqual(
            try request(["tag": "a", "caller": String(repeating: "x", count: 200)]).caller?.count,
            IncomingCallRequest.maximumCallerLength
        )
    }

    // MARK: - Video and timeout

    func testVideoDefaultsToTrue() throws {
        XCTAssertTrue(try request(["tag": "a"]).hasVideo)
        XCTAssertFalse(try request(["tag": "a", "video": false]).hasVideo)
        XCTAssertTrue(try request(["tag": "a", "video": "no"]).hasVideo)
    }

    func testTimeoutIsClamped() throws {
        XCTAssertEqual(try request(["tag": "a"]).timeout, IncomingCallRequest.defaultTimeout)
        XCTAssertEqual(try request(["tag": "a", "timeout": 30]).timeout, 30)
        XCTAssertEqual(try request(["tag": "a", "timeout": 30.5]).timeout, 30.5)
        XCTAssertEqual(try request(["tag": "a", "timeout": "20"]).timeout, 20)
        XCTAssertEqual(try request(["tag": "a", "timeout": 1]).timeout, 10)
        XCTAssertEqual(try request(["tag": "a", "timeout": -5]).timeout, 10)
        XCTAssertEqual(try request(["tag": "a", "timeout": 100_000]).timeout, 120)
        XCTAssertEqual(try request(["tag": "a", "timeout": Double.nan]).timeout, IncomingCallRequest.defaultTimeout)
        XCTAssertEqual(try request(["tag": "a", "timeout": "soon"]).timeout, IncomingCallRequest.defaultTimeout)
    }

    // MARK: - URL

    func testRelativePathIsAccepted() throws {
        XCTAssertEqual(try request(["tag": "a", "url": "/lovelace/0#visio"]).url, "/lovelace/0#visio")
        XCTAssertEqual(try request(["tag": "a", "url": " /visio "]).url, "/visio")
    }

    func testURLsLeavingTheServerAreDropped() throws {
        for url in [
            "//evil.example/phish",
            "/\\evil.example",
            "https://evil.example/lovelace",
            "https://homeassistant.local.evil.example:8123/",
            "http://homeassistant.local:9999/",
            "http://user:pass@homeassistant.local:8123/",
            "javascript:alert(1)",
            "file:///etc/passwd",
            "homeassistant://navigate/lovelace",
            "lovelace/0",
            "/" + String(repeating: "a", count: 2048),
        ] {
            XCTAssertNil(try request(["tag": "a", "url": url]).url, url)
        }
        XCTAssertNil(try request(["tag": "a", "url": 3]).url)
    }

    func testAbsoluteURLToTheServerIsAccepted() throws {
        XCTAssertEqual(
            try request(["tag": "a", "url": "http://HomeAssistant.local:8123/lovelace/0"]).url,
            "http://HomeAssistant.local:8123/lovelace/0"
        )
        XCTAssertEqual(
            try request(["tag": "a", "url": "https://example.ui.nabu.casa/visio"]).url,
            "https://example.ui.nabu.casa/visio"
        )
    }

    func testAbsoluteURLIsDroppedWithoutServerURLs() throws {
        let result = IncomingCallRequest.parse(homeassistant: [
            "command": "incoming_call",
            "tag": "a",
            "url": "http://homeassistant.local:8123/lovelace/0",
        ])
        XCTAssertNil(try result.get().url)
    }

    // MARK: - Action data and server

    func testActionDataIsTheDictionaryWithoutInternalKeys() throws {
        let parsed = try request([
            "tag": "a",
            "room": "salon",
            "webhook_id": "hook",
            "hass_confirm_id": "confirm",
        ])
        XCTAssertEqual(parsed.webhookID, "hook")
        XCTAssertEqual(parsed.actionData as NSDictionary, ["tag": "a", "room": "salon"] as NSDictionary)
    }

    func testUserInfoWebhookIDIsUsed() throws {
        let parsed = try IncomingCallRequest.parse(userInfo: [
            "webhook_id": "hook",
            "homeassistant": ["command": "incoming_call", "tag": "a"],
        ]).get()
        XCTAssertEqual(parsed.webhookID, "hook")
        XCTAssertTrue(IncomingCallRequest.isIncomingCall(userInfo: ["homeassistant": ["command": "incoming_call"]]))
        XCTAssertFalse(IncomingCallRequest.isIncomingCall(userInfo: ["homeassistant": ["command": "other"]]))
        XCTAssertFalse(IncomingCallRequest.isIncomingCall(userInfo: [:]))
    }
}
