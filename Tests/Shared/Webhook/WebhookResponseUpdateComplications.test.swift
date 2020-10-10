import Foundation
@testable import Shared
import PromiseKit
import XCTest
import RealmSwift

class WebhookResponseUpdateComplicationsTests: XCTestCase {
    private var api: FakeHomeAssistantAPI!
    private var webhookManager: FakeWebhookManager!
    private var realm: Realm!

    override func setUpWithError() throws {
        try super.setUpWithError()

        let executionIdentifier = UUID().uuidString

        realm = try Realm(configuration: .init(inMemoryIdentifier: executionIdentifier))
        Current.realm = { self.realm }

        api = FakeHomeAssistantAPI(
            tokenInfo: .init(
                accessToken: "atoken",
                refreshToken: "refreshtoken",
                expiration: Date()
            )
        )
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
                $0.Template = .ExtraLargeColumnsText
                $0.resultRawRendered = [
                    "fwc1k1": "fwc1v1",
                    "fwc1k2": "fwc1v2"
                ]
            },
            with(FakeWatchComplication()) {
                $0.Template = .CircularSmallRingText
                $0.resultRawRendered = [:]
            },
            with(FakeWatchComplication()) {
                $0.Template = .GraphicBezelCircularText
                $0.resultRawRendered = [
                    "fwc3k1": "fwc3v1"
                ]
            },
        ]

        let request = WebhookResponseUpdateComplications.request(for: Set(complications))
        XCTAssertEqual(request?.type, "render_template")

        let expected: [String: [String: String]] = [
            complications[0].Template.rawValue + "|fwc1k1": [
                "template": "fwc1v1"
            ],
            complications[0].Template.rawValue + "|fwc1k2": [
                "template": "fwc1v2"
            ],
            complications[2].Template.rawValue + "|fwc3k1": [
                "template": "fwc3v1"
            ]
        ]

        XCTAssertEqual(request?.data as? [String: [String: String]], expected)
    }

    func testResponseUpdatesComplication() throws {
        let complications = [
            with(FakeWatchComplication()) {
                $0.Template = .ExtraLargeColumnsText
                $0.Family = .extraLarge
                $0.resultRawRendered = [
                    "fwc1k1": "fwc1v1",
                    "fwc1k2": "fwc1v2"
                ]
            },
            with(FakeWatchComplication()) {
                $0.Template = .CircularSmallRingText
                $0.Family = .circularSmall
                $0.resultRawRendered = [:]
            },
            with(FakeWatchComplication()) {
                $0.Template = .GraphicBezelCircularText
                $0.Family = .graphicBezel
                $0.resultRawRendered = [
                    "fwc3k1": "fwc3v1"
                ]
            },
        ]
        try realm.write {
            realm.add(complications)
        }

        var handler = WebhookResponseUpdateComplications(api: api)
        handler.watchComplicationClass = FakeWatchComplication.self

        let request = WebhookResponseUpdateComplications.request(for: Set(complications))!
        let result: [String: String] = [
            complications[0].Template.rawValue + "|fwc1k1": "rendered_fwc1v1",
            complications[0].Template.rawValue + "|fwc1k2": "rendered_fwc1v2",
            complications[2].Template.rawValue + "|fwc3k1": "rendered_fwc3v1",
        ]

        let expectation = self.expectation(description: "result")
        handler.handle(request: .value(request), result: .value(result)).done { handlerResult in
            XCTAssertNil(handlerResult.notification)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10)

        XCTAssertEqual(FakeWatchComplication.rawRenderedUpdates, [
            complications[0].Template.rawValue: [
                "fwc1k1": "rendered_fwc1v1",
                "fwc1k2": "rendered_fwc1v2"
            ],
            complications[2].Template.rawValue: [
                "fwc3k1": "rendered_fwc3v1"
            ]
        ])
    }
}

private class FakeHomeAssistantAPI: HomeAssistantAPI {

}

class FakeWatchComplication: WatchComplication {
    var resultRawRendered: [String: String] = [:]

    override func rawRendered() -> [String : String] {
        resultRawRendered
    }

    static var rawRenderedUpdates: [String: [String: String]] = [:]

    override func updateRawRendered(from response: [String : String]) {
        Self.rawRenderedUpdates[Template.rawValue] = response
    }
}
