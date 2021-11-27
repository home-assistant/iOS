import Foundation
import PromiseKit
@testable import Shared
import XCTest

class WebhookResponseServiceCallTests: XCTestCase {
    private var api: HomeAssistantAPI!

    enum TestError: Error {
        case any
    }

    override func setUp() {
        super.setUp()

        api = HomeAssistantAPI(server: .fake())
    }

    func testReplacement() throws {
        let request1 = WebhookRequest(type: "call_service", data: [
            "domain": "domain",
            "service": "service",
            "service_data": ["dog": "bark"],
        ])
        let request2 = WebhookRequest(type: "call_service", data: [
            "domain": "domain",
            "service": "service",
            "service_data": ["dog": "bark"],
        ])
        let request3 = WebhookRequest(type: "call_service", data: [
            "domain": "domain",
            "service": "service2",
            "service_data": ["cat": "meow"],
        ])

        XCTAssertFalse(WebhookResponseServiceCall.shouldReplace(request: request1, with: request2))
        XCTAssertFalse(WebhookResponseServiceCall.shouldReplace(request: request2, with: request3))
        XCTAssertFalse(WebhookResponseServiceCall.shouldReplace(request: request3, with: request1))
    }

    func testSuccessful() {
        let handler = WebhookResponseServiceCall(api: api)
        let promise = handler.handle(
            request: .value(WebhookRequest(type: "call_service", data: [
                "domain": "domain",
                "service": "service",
                "service_data": ["dog": "bark"],
            ])), result: .value([:])
        )

        XCTAssertNil(try hang(Promise(promise)).notification)
    }

    func testFailure() {
        let handler = WebhookResponseServiceCall(api: api)
        let promise = handler.handle(
            request: .value(WebhookRequest(type: "call_service", data: [
                "domain": "domain",
                "service": "service",
                "service_data": ["dog": "bark"],
            ])), result: .init(error: TestError.any)
        )

        XCTAssertNil(try hang(Promise(promise)).notification)
    }
}
