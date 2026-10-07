import Foundation
import GRDB
import PromiseKit
@testable import Shared
import XCTest

class WebhookResponseUpdateComplicationsTests: XCTestCase {
    private var api: FakeHomeAssistantAPI!
    private var webhookManager: FakeWebhookManager!

    override func setUpWithError() throws {
        try super.setUpWithError()

        api = FakeHomeAssistantAPI(server: .fake())
        webhookManager = FakeWebhookManager()
        Current.webhooks = webhookManager

        // WatchComplication is now a GRDB record; start each test with a clean table.
        try Current.database().write { db in
            try WatchComplication.deleteAll(db)
        }
    }

    override func tearDown() {
        api = nil
        webhookManager = nil
        try? Current.database().write { db in
            try WatchComplication.deleteAll(db)
        }
        super.tearDown()
    }

    /// Builds a complication whose `ExtraLargeColumnsText` text areas hold the given templates. Only
    /// values containing a Jinja template are surfaced by `rawRendered()`, keyed as `textArea,<slug>`.
    private func makeComplication(
        identifier: String,
        serverIdentifier: String,
        textAreas: [String: String]
    ) -> WatchComplication {
        var complication = WatchComplication(
            identifier: identifier,
            serverIdentifier: serverIdentifier,
            family: .extraLarge,
            template: .ExtraLargeColumnsText
        )
        var areas: [String: [String: Any]] = [:]
        for (slug, text) in textAreas {
            areas[slug] = ["text": text, "color": "#ffffffff"]
        }
        complication.Data = ["textAreas": areas]
        return complication
    }

    func testNoComplicationGivesNoRequest() {
        XCTAssertNil(WebhookResponseUpdateComplications.request(for: [WatchComplication]()))
    }

    func testComplicationsWithoutTemplatesGiveNoRequest() {
        let complications = [
            makeComplication(identifier: "c1", serverIdentifier: "s", textAreas: ["Row1Column1": "static"]),
            makeComplication(identifier: "c2", serverIdentifier: "s", textAreas: ["Row1Column1": "also static"]),
        ]
        XCTAssertNil(WebhookResponseUpdateComplications.request(for: complications))
    }

    func testComplicationsWithTemplatesProduceRequest() {
        let complications = [
            makeComplication(
                identifier: "c1",
                serverIdentifier: api.server.identifier.rawValue,
                textAreas: ["Row1Column1": "{{ states('sensor.one') }}"]
            ),
            makeComplication(
                identifier: "c2",
                serverIdentifier: api.server.identifier.rawValue,
                textAreas: ["Row1Column1": "static"]
            ),
        ]

        let request = WebhookResponseUpdateComplications.request(for: complications)
        XCTAssertEqual(request?.type, "render_template")

        let expected: [String: [String: String]] = [
            "c1|textArea,Row1Column1": ["template": "{{ states('sensor.one') }}"],
        ]
        XCTAssertEqual(request?.data as? [String: [String: String]], expected)
    }

    func testResponseUpdatesComplicationInDatabase() throws {
        let complication = makeComplication(
            identifier: "c1",
            serverIdentifier: api.server.identifier.rawValue,
            textAreas: ["Row1Column1": "{{ states('sensor.one') }}"]
        )
        try complication.save()

        let handler = WebhookResponseUpdateComplications(api: api)
        let request = WebhookResponseUpdateComplications.request(for: [complication])!
        let result: [String: Any] = [
            "c1|textArea,Row1Column1": "rendered_value",
        ]

        let expectation = expectation(description: "result")
        handler.handle(request: .value(request), result: .value(result)).done { handlerResult in
            XCTAssertNil(handlerResult.notification)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 30)

        let stored = try Current.database().read { db in
            try WatchComplication.fetchOne(db, key: "c1")
        }
        let rendered = stored?.renderedValues()
        XCTAssertEqual(rendered?[.textArea("Row1Column1")] as? String, "rendered_value")
    }
}

private class FakeHomeAssistantAPI: HomeAssistantAPI {}
