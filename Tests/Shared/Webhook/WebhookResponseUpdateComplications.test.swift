import Foundation
import PromiseKit
import RealmSwift
@testable import Shared
import XCTest

class WebhookResponseUpdateComplicationsTests: XCTestCase {
    private var api: FakeHomeAssistantAPI!
    private var webhookManager: FakeWebhookManager!
    private var realm: Realm!

    override func setUpWithError() throws {
        try super.setUpWithError()

        let executionIdentifier = UUID().uuidString

        realm = try Realm(configuration: .init(inMemoryIdentifier: executionIdentifier))
        Current.realm = { self.realm }

        api = FakeHomeAssistantAPI(server: .fake())
        webhookManager = FakeWebhookManager()
        Current.webhooks = webhookManager

        FakeWatchComplication.rawRenderedUpdates = [:]
    }

    func testNoComplicationGivesNoRequest() {
        XCTAssertNil(WebhookResponseUpdateComplications.request(for: .init()))
    }

    func testComplicationsWithoutPreRendered() {
        let complications = Set([
            FakeWatchComplication(),
            FakeWatchComplication(),
            FakeWatchComplication(),
        ])

        XCTAssertNil(WebhookResponseUpdateComplications.request(for: complications))
    }

    func testComplicationsWithPreRendered() {
        let complications = [
            with(FakeWatchComplication()) {
                $0.identifier = "c1"
                $0.serverIdentifier = api.server.identifier.rawValue
                $0.Template = .ExtraLargeColumnsText
                $0.resultRawRendered = [
                    "fwc1k1": "fwc1v1",
                    "fwc1k2": "fwc1v2",
                ]
            },
            with(FakeWatchComplication()) {
                $0.identifier = "c2"
                $0.serverIdentifier = api.server.identifier.rawValue
                $0.Template = .CircularSmallRingText
                $0.resultRawRendered = [:]
            },
            with(FakeWatchComplication()) {
                $0.identifier = "c3"
                $0.serverIdentifier = api.server.identifier.rawValue
                $0.Template = .GraphicBezelCircularText
                $0.resultRawRendered = [
                    "fwc3k1": "fwc3v1",
                ]
            },
            with(FakeWatchComplication()) {
                $0.identifier = "bad1"
                $0.serverIdentifier = UUID().uuidString
                $0.Template = .ExtraLargeColumnsText
            },
        ]

        let request = WebhookResponseUpdateComplications.request(for: Set(complications))
        XCTAssertEqual(request?.type, "render_template")

        let expected: [String: [String: String]] = [
            "c1|fwc1k1": [
                "template": "fwc1v1",
            ],
            "c1|fwc1k2": [
                "template": "fwc1v2",
            ],
            "c3|fwc3k1": [
                "template": "fwc3v1",
            ],
        ]

        XCTAssertEqual(request?.data as? [String: [String: String]], expected)
    }

    func testResponseUpdatesComplication() throws {
        let complications = [
            with(FakeWatchComplication()) {
                $0.identifier = "c1"
                $0.serverIdentifier = api.server.identifier.rawValue
                $0.Template = .ExtraLargeColumnsText
                $0.Family = .extraLarge
                $0.resultRawRendered = [
                    "fwc1k1": "fwc1v1",
                    "fwc1k2": "fwc1v2",
                ]
            },
            with(FakeWatchComplication()) {
                $0.identifier = "c2"
                $0.serverIdentifier = api.server.identifier.rawValue
                $0.Template = .CircularSmallRingText
                $0.Family = .circularSmall
                $0.resultRawRendered = [:]
            },
            with(FakeWatchComplication()) {
                $0.identifier = "c3"
                $0.serverIdentifier = api.server.identifier.rawValue
                $0.Template = .GraphicBezelCircularText
                $0.Family = .graphicBezel
                $0.resultRawRendered = [
                    "fwc3k1": "fwc3v1",
                ]
            },
            with(FakeWatchComplication()) {
                $0.identifier = "bad1"
                $0.serverIdentifier = UUID().uuidString
                $0.Template = .ExtraLargeColumnsText
            },
        ]
        try realm.write {
            realm.add(complications)
        }

        var handler = WebhookResponseUpdateComplications(api: api)
        handler.watchComplicationClass = FakeWatchComplication.self

        let request = WebhookResponseUpdateComplications.request(for: Set(complications))!
        let result: [String: Any] = [
            "c1|fwc1k1": "rendered_fwc1v1",
            "c1|fwc1k2": "rendered_fwc1v2",
            "c3|fwc3k1": 3,
        ]

        let expectation = self.expectation(description: "result")
        handler.handle(request: .value(request), result: .value(result)).done { handlerResult in
            XCTAssertNil(handlerResult.notification)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10)

        let complication0Updates = FakeWatchComplication.rawRenderedUpdates["c1"]
        let complication2Updates = FakeWatchComplication.rawRenderedUpdates["c3"]

        XCTAssertEqual(
            complication0Updates?["fwc1k1"] as? String,
            "rendered_fwc1v1"
        )

        XCTAssertEqual(
            complication0Updates?["fwc1k2"] as? String,
            "rendered_fwc1v2"
        )

        XCTAssertEqual(
            complication2Updates?["fwc3k1"] as? Int,
            3
        )

        XCTAssertNil(FakeWatchComplication.rawRenderedUpdates["bad1"])
    }
}

private class FakeHomeAssistantAPI: HomeAssistantAPI {}

class FakeWatchComplication: WatchComplication {
    var resultRawRendered: [String: String] = [:]

    override func rawRendered() -> [String: String] {
        resultRawRendered
    }

    static var rawRenderedUpdates: [String: [String: Any]] = [:]

    override func updateRawRendered(from response: [String: Any]) {
        Self.rawRenderedUpdates[identifier] = response
    }
}
