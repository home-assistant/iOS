import Foundation
import PromiseKit
@testable import Shared
import XCTest

class WebhookResponseUnhandledTests: XCTestCase {
    private var api: HomeAssistantAPI!

    enum TestError: Error {
        case any
    }

    override func setUp() {
        super.setUp()

        api = HomeAssistantAPI(server: .fake())
    }

    func testReplacement() throws {
        let request1 = WebhookRequest(type: "any", data: [:])
        let request2 = WebhookRequest(type: "any", data: [:])
        let request3 = WebhookRequest(type: "any2", data: [:])

        XCTAssertFalse(WebhookResponseUnhandled.shouldReplace(request: request1, with: request2))
        XCTAssertFalse(WebhookResponseUnhandled.shouldReplace(request: request2, with: request3))
        XCTAssertFalse(WebhookResponseUnhandled.shouldReplace(request: request3, with: request1))
    }
}
