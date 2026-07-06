import Foundation
import GRDB
import PromiseKit
@testable import Shared
import XCTest

class WebhookResponseUpdateComplicationsTests: XCTestCase {
    private var api: FakeHomeAssistantAPI!
    private var webhookManager: FakeWebhookManager!
    private var database: DatabaseQueue!
    private var previousDatabase: (() -> DatabaseQueue)!

    override func setUpWithError() throws {
        try super.setUpWithError()

        database = try DatabaseQueue()
        try WatchComplicationTable().createIfNeeded(database: database)
        previousDatabase = Current.database
        Current.database = { self.database }

        api = FakeHomeAssistantAPI(server: .fake())
        webhookManager = FakeWebhookManager()
        Current.webhooks = webhookManager
    }

    override func tearDown() {
        Current.database = previousDatabase
        api = nil
        webhookManager = nil
        database = nil

        super.tearDown()
    }

    private func makeComplication(
        identifier: String,
        serverIdentifier: String,
        template: ComplicationTemplate,
        textAreaTemplates: [String: String] = [:]
    ) -> WatchComplication {
        let complication = WatchComplication()
        complication.identifier = identifier
        complication.serverIdentifier = serverIdentifier
        complication.Template = template

        if !textAreaTemplates.isEmpty {
            complication.Data = [
                "textAreas": textAreaTemplates.mapValues { text in
                    ["text": text, "color": "#ffffff"]
                },
            ]
        }

        return complication
    }

    func testNoComplicationGivesNoRequest() {
        XCTAssertNil(WebhookResponseUpdateComplications.request(for: .init()))
    }

    func testComplicationsWithoutPreRendered() {
        let complications = Set([
            WatchComplication(),
            WatchComplication(),
            WatchComplication(),
        ])

        XCTAssertNil(WebhookResponseUpdateComplications.request(for: complications))
    }

    func testComplicationsWithPreRendered() {
        let complications = [
            makeComplication(
                identifier: "c1",
                serverIdentifier: api.server.identifier.rawValue,
                template: .ExtraLargeColumnsText,
                textAreaTemplates: [
                    "Row1Column1": "{{ states('sensor.one') }}",
                    "Row1Column2": "{{ states('sensor.two') }}",
                ]
            ),
            makeComplication(
                identifier: "c2",
                serverIdentifier: api.server.identifier.rawValue,
                template: .CircularSmallRingText
            ),
            makeComplication(
                identifier: "c3",
                serverIdentifier: api.server.identifier.rawValue,
                template: .GraphicBezelCircularText,
                textAreaTemplates: [
                    "Center": "{{ states('sensor.three') }}",
                ]
            ),
        ]

        let request = WebhookResponseUpdateComplications.request(for: Set(complications))
        XCTAssertEqual(request?.type, "render_template")

        let expected: [String: [String: String]] = [
            "c1|textArea,Row1Column1": [
                "template": "{{ states('sensor.one') }}",
            ],
            "c1|textArea,Row1Column2": [
                "template": "{{ states('sensor.two') }}",
            ],
            "c3|textArea,Center": [
                "template": "{{ states('sensor.three') }}",
            ],
        ]

        XCTAssertEqual(request?.data as? [String: [String: String]], expected)
    }

    func testResponseUpdatesComplication() throws {
        let complications = [
            makeComplication(
                identifier: "c1",
                serverIdentifier: api.server.identifier.rawValue,
                template: .ExtraLargeColumnsText,
                textAreaTemplates: [
                    "Row1Column1": "{{ states('sensor.one') }}",
                    "Row1Column2": "{{ states('sensor.two') }}",
                ]
            ),
            makeComplication(
                identifier: "c2",
                serverIdentifier: api.server.identifier.rawValue,
                template: .CircularSmallRingText
            ),
            makeComplication(
                identifier: "c3",
                serverIdentifier: api.server.identifier.rawValue,
                template: .GraphicBezelCircularText,
                textAreaTemplates: [
                    "Center": "{{ states('sensor.three') }}",
                ]
            ),
        ]

        try database.write { db in
            for complication in complications {
                try complication.save(db)
            }
        }

        let handler = WebhookResponseUpdateComplications(api: api)

        let request = WebhookResponseUpdateComplications.request(for: Set(complications))!
        let result: [String: Any] = [
            "c1|textArea,Row1Column1": "rendered_one",
            "c1|textArea,Row1Column2": "rendered_two",
            "c3|textArea,Center": 3,
        ]

        let expectation = expectation(description: "result")
        handler.handle(request: .value(request), result: .value(result)).done { handlerResult in
            XCTAssertNil(handlerResult.notification)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 30)

        let updated1 = try XCTUnwrap(WatchComplication.fetch(identifier: "c1"))
        let updated2 = try XCTUnwrap(WatchComplication.fetch(identifier: "c2"))
        let updated3 = try XCTUnwrap(WatchComplication.fetch(identifier: "c3"))

        let rendered1 = updated1.Data["rendered"] as? [String: Any]
        XCTAssertEqual(rendered1?["textArea,Row1Column1"] as? String, "rendered_one")
        XCTAssertEqual(rendered1?["textArea,Row1Column2"] as? String, "rendered_two")

        XCTAssertNil(updated2.Data["rendered"])

        let rendered3 = updated3.Data["rendered"] as? [String: Any]
        XCTAssertEqual(rendered3?["textArea,Center"] as? Int, 3)
    }
}

private class FakeHomeAssistantAPI: HomeAssistantAPI {}
