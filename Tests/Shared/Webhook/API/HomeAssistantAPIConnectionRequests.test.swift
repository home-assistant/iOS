import Foundation
import HAKit
import HAKit_Mocks
import PromiseKit
@testable import Shared
import XCTest

final class HomeAssistantAPIConnectionRequestsTests: XCTestCase {
    private var api: HomeAssistantAPI!
    private var connection: HAMockConnection!

    override func setUp() {
        super.setUp()
        api = HomeAssistantAPI(server: .fake())
        connection = HAMockConnection()
        connection.automaticallyTransitionToConnecting = false
        api.connection = connection
    }

    override func tearDown() {
        api = nil
        connection = nil
        super.tearDown()
    }

    private func answerOnlyRequest(with data: HAData) throws -> HARequest {
        XCTAssertEqual(connection.pendingRequests.count, 1)
        let pending = try XCTUnwrap(connection.pendingRequests.first)
        pending.completion(.success(data))
        return pending.request
    }

    // MARK: - callServiceWithResponse

    func testCallServiceWithResponseReturnsTheActionResponse() throws {
        let promise = api.callServiceWithResponse(
            domain: "weather",
            service: "get_forecasts",
            serviceData: ["entity_id": "weather.home"],
            returnResponse: true
        )

        let request = try answerOnlyRequest(with: .dictionary([
            "context": ["id": "abc"],
            "response": ["weather.home": ["forecast": []]],
        ]))
        let response = try hang(promise)

        XCTAssertTrue(response.hasResponse)
        XCTAssertEqual(request.type, .webSocket("call_service"))
        XCTAssertEqual(request.data["domain"] as? String, "weather")
        XCTAssertEqual(request.data["service"] as? String, "get_forecasts")
        XCTAssertEqual(request.data["return_response"] as? Bool, true)
    }

    func testCallServiceWithResponsePropagatesFailures() throws {
        let promise = api.callServiceWithResponse(
            domain: "light",
            service: "turn_on",
            serviceData: [:],
            returnResponse: false
        )

        let pending = try XCTUnwrap(connection.pendingRequests.first)
        pending.completion(.failure(.internal(debugDescription: "boom")))

        XCTAssertThrowsError(try hang(promise))
    }

    // MARK: - executeActionForDomainType

    func testUnlockedLockGetsLocked() throws {
        let promise = api.executeActionForDomainType(domain: .lock, entityId: "lock.front", state: "unlocked")

        let request = try answerOnlyRequest(with: .empty)
        try hang(promise)

        XCTAssertEqual(request.data["domain"] as? String, "lock")
        XCTAssertEqual(request.data["service"] as? String, "lock")
        XCTAssertEqual((request.data["target"] as? [String: String])?["entity_id"], "lock.front")
    }

    func testOpeningLockGetsLocked() throws {
        let promise = api.executeActionForDomainType(domain: .lock, entityId: "lock.front", state: "opening")

        let request = try answerOnlyRequest(with: .empty)
        try hang(promise)

        XCTAssertEqual(request.data["service"] as? String, "lock")
    }

    func testLockedLockGetsUnlocked() throws {
        let promise = api.executeActionForDomainType(domain: .lock, entityId: "lock.front", state: "locked")

        let request = try answerOnlyRequest(with: .empty)
        try hang(promise)

        XCTAssertEqual(request.data["service"] as? String, "unlock")
    }

    func testJammedLockSendsNothing() throws {
        try hang(api.executeActionForDomainType(domain: .lock, entityId: "lock.front", state: "jammed"))

        XCTAssertTrue(connection.pendingRequests.isEmpty)
    }

    func testLockInUnknownStateSendsNothing() throws {
        try hang(api.executeActionForDomainType(domain: .lock, entityId: "lock.front", state: "not-a-state"))

        XCTAssertTrue(connection.pendingRequests.isEmpty)
    }

    func testLightRunsItsMainAction() throws {
        let promise = api.executeActionForDomainType(domain: .light, entityId: "light.kitchen", state: "on")

        let request = try answerOnlyRequest(with: .empty)
        try hang(promise)

        XCTAssertEqual(request.data["domain"] as? String, "light")
        XCTAssertEqual(request.data["service"] as? String, "toggle")
    }

    func testDomainWithoutMainActionSendsNothing() throws {
        try hang(api.executeActionForDomainType(domain: .sensor, entityId: "sensor.temperature", state: "21"))

        XCTAssertTrue(connection.pendingRequests.isEmpty)
    }

    // MARK: - currentUser / profile picture

    func testCurrentUserIsNilWhenTheRequestFails() throws {
        var results = [HAResponseCurrentUser?]()
        api.currentUser { results.append($0) }

        let pending = try XCTUnwrap(connection.pendingRequests.first)
        pending.completion(.failure(.internal(debugDescription: "offline")))

        XCTAssertEqual(results.count, 1)
        XCTAssertNil(results.first ?? nil)
    }

    func testProfilePictureURLIsNilWithoutACurrentUser() throws {
        var results = [URL?]()
        api.profilePictureURL { results.append($0) }

        let pending = try XCTUnwrap(connection.pendingRequests.first)
        XCTAssertEqual(pending.request.type, .webSocket("auth/current_user"))
        pending.completion(.failure(.internal(debugDescription: "offline")))

        XCTAssertEqual(results.count, 1)
        XCTAssertNil(results.first ?? nil)
        // No user means no states lookup.
        XCTAssertEqual(connection.pendingRequests.count, 1)
    }

    func testCancelledProfilePictureURLNeverCompletes() throws {
        var results = [URL?]()
        let cancellable = api.profilePictureURL { results.append($0) }
        cancellable.cancel()

        let pending = try XCTUnwrap(connection.pendingRequests.first)
        XCTAssertTrue(pending.cancellable.wasCancelled)
        pending.completion(.failure(.internal(debugDescription: "offline")))

        XCTAssertTrue(results.isEmpty)
    }
}
