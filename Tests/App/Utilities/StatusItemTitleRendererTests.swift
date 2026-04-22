import HAKit
@testable import HomeAssistant
@testable import Shared
import XCTest

final class StatusItemTitleRendererTests: XCTestCase {
    private var api: HomeAssistantAPI!
    private var connection: HAMockConnection!

    override func setUp() {
        super.setUp()
        connection = HAMockConnection()
        api = HomeAssistantAPI(server: .fake())
        api.connection = connection
        connection.automaticallyTransitionToConnecting = false
    }

    override func tearDown() {
        super.tearDown()
        api = nil
        connection = nil
    }

    func testSubscribeStartsRestFallbackAndLiveSubscription() throws {
        let token = StatusItemTitleRenderer.subscribe(api: api, template: "{{ now() }}") { _ in }

        let pendingRequest = try XCTUnwrap(connection.pendingRequests.first)
        XCTAssertEqual(pendingRequest.request.type, .rest(.post, "template"))
        XCTAssertEqual(pendingRequest.request.data["template"] as? String, "{{ now() }}")

        let pendingSubscription = try XCTUnwrap(connection.pendingSubscriptions.first)
        XCTAssertEqual(pendingSubscription.request.type, .renderTemplate)
        XCTAssertEqual(pendingSubscription.request.data["template"] as? String, "{{ now() }}")

        token.cancel()

        XCTAssertEqual(connection.cancelledRequests.count, 1)
        XCTAssertEqual(connection.cancelledSubscriptions.count, 1)
    }

    func testRestFallbackDoesNotOverrideLiveUpdate() throws {
        var updates = [String]()
        _ = StatusItemTitleRenderer.subscribe(api: api, template: "{{ now() }}") { updates.append($0) }

        let pendingSubscription = try XCTUnwrap(connection.pendingSubscriptions.first)
        pendingSubscription.handler(pendingSubscription.cancellable, .dictionary([
            "result": "live value",
            "listeners": [:],
        ]))

        let pendingRequest = try XCTUnwrap(connection.pendingRequests.first)
        pendingRequest.completion(.success(.primitive("rest value")))

        XCTAssertEqual(updates, ["live value"])
    }

    func testRestFallbackPreventsErrorLabelWhenSubscriptionFails() throws {
        var updates = [String]()
        _ = StatusItemTitleRenderer.subscribe(api: api, template: "{{ now() }}") { updates.append($0) }

        let pendingRequest = try XCTUnwrap(connection.pendingRequests.first)
        pendingRequest.completion(.success(.primitive("rest value")))

        let pendingSubscription = try XCTUnwrap(connection.pendingSubscriptions.first)
        pendingSubscription.initiated(.failure(.internal(debugDescription: "unit-test")))

        XCTAssertEqual(updates, ["rest value"])
    }

    func testSubscriptionFailureShowsErrorWhenNoRenderSucceeded() throws {
        var updates = [String]()
        _ = StatusItemTitleRenderer.subscribe(api: api, template: "{{ now() }}") { updates.append($0) }

        let pendingSubscription = try XCTUnwrap(connection.pendingSubscriptions.first)
        pendingSubscription.initiated(.failure(.internal(debugDescription: "unit-test")))

        XCTAssertEqual(updates, [L10n.errorLabel])
    }
}
