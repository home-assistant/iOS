import HAKit
@testable import Shared
import XCTest

final class HomeAssistantAPIIdentityTests: XCTestCase {
    override func tearDown() {
        ServerFixture.reset()
        super.tearDown()
    }

    func testCurrentUserUsesRestEndpoint() {
        let api = HomeAssistantAPI(server: ServerFixture.withRemoteConnection)
        let connection = FakeHAConnection()
        connection.mockResponses["auth/current_user"] = .dictionary([
            "id": "user-id",
            "name": "cepresso",
            "is_owner": false,
            "is_admin": true,
            "credentials": [],
            "mfa_modules": [],
        ])
        api.connection = connection

        let expectation = expectation(description: "current user")

        api.currentUser { user in
            XCTAssertEqual(user?.id, "user-id")
            XCTAssertEqual(user?.name, "cepresso")
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(connection.sentRequests.count, 1)

        guard case let .rest(method, command) = connection.sentRequests[0].type else {
            XCTFail("Expected REST request")
            return
        }

        XCTAssertEqual(method, .get)
        XCTAssertEqual(command, "auth/current_user")
    }

    func testProfilePictureURLUsesRestRequests() {
        let api = HomeAssistantAPI(server: ServerFixture.withRemoteConnection)
        let connection = FakeHAConnection()
        connection.mockResponses["auth/current_user"] = .dictionary([
            "id": "user-id",
            "name": "cepresso",
            "is_owner": false,
            "is_admin": true,
            "credentials": [],
            "mfa_modules": [],
        ])
        connection.mockResponses["states"] = .array([
            .dictionary([
                "entity_id": "person.cepresso",
                "state": "home",
                "last_changed": "2026-04-23T10:00:00Z",
                "last_updated": "2026-04-23T10:00:00Z",
                "attributes": [
                    "user_id": "user-id",
                    "entity_picture": "/api/image/serve/abc/original?token=123",
                ],
                "context": [
                    "id": "context-id",
                ],
            ]),
        ])
        api.connection = connection

        let expectation = expectation(description: "profile picture URL")

        api.profilePictureURL { url in
            XCTAssertEqual(
                url?.absoluteString,
                "https://external.example.com/api/image/serve/abc/original?token=123"
            )
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(connection.sentRequests.count, 2)

        guard case let .rest(firstMethod, firstCommand) = connection.sentRequests[0].type else {
            XCTFail("Expected first request to use REST")
            return
        }

        XCTAssertEqual(firstMethod, .get)
        XCTAssertEqual(firstCommand, "auth/current_user")

        guard case let .rest(secondMethod, secondCommand) = connection.sentRequests[1].type else {
            XCTFail("Expected second request to use REST")
            return
        }

        XCTAssertEqual(secondMethod, .get)
        XCTAssertEqual(secondCommand, "states")
    }
}

private final class FakeHAConnection: HAConnection {
    weak var delegate: HAConnectionDelegate?
    var configuration = HAConnectionConfiguration(
        connectionInfo: { nil },
        fetchAuthToken: { completion in completion(.success("token")) }
    )
    var state: HAConnectionState = .disconnected(reason: .disconnected)
    lazy var caches: HACachesContainer = .init(connection: self)
    var callbackQueue: DispatchQueue = .main

    var sentRequests = [HARequest]()
    var mockResponses = [String: HAData]()

    func connect() {}

    func disconnect() {}

    @discardableResult
    func send(
        _ request: HARequest,
        completion: @escaping RequestCompletion
    ) -> HACancellable {
        sentRequests.append(request)
        completion(.failure(.internal(debugDescription: "Raw request not mocked")))
        return HANoopCancellable()
    }

    @discardableResult
    func send<T>(
        _ request: HATypedRequest<T>,
        completion: @escaping (Result<T, HAError>) -> Void
    ) -> HACancellable where T: HADataDecodable {
        sentRequests.append(request.request)

        let command = request.request.type.command

        guard let data = mockResponses[command] else {
            completion(.failure(.internal(debugDescription: "Missing mock response for \(command)")))
            return HANoopCancellable()
        }

        do {
            try completion(.success(T(data: data)))
        } catch {
            completion(.failure(.underlying(error as NSError)))
        }

        return HANoopCancellable()
    }

    @discardableResult
    func subscribe(
        to request: HARequest,
        handler: @escaping SubscriptionHandler
    ) -> HACancellable {
        sentRequests.append(request)
        return HANoopCancellable()
    }

    @discardableResult
    func subscribe(
        to request: HARequest,
        initiated: @escaping SubscriptionInitiatedHandler,
        handler: @escaping SubscriptionHandler
    ) -> HACancellable {
        sentRequests.append(request)
        initiated(.failure(.internal(debugDescription: "Subscriptions not mocked")))
        return HANoopCancellable()
    }

    @discardableResult
    func subscribe<T>(
        to request: HATypedSubscription<T>,
        handler: @escaping (HACancellable, T) -> Void
    ) -> HACancellable {
        sentRequests.append(request.request)
        return HANoopCancellable()
    }

    @discardableResult
    func subscribe<T>(
        to request: HATypedSubscription<T>,
        initiated: @escaping SubscriptionInitiatedHandler,
        handler: @escaping (HACancellable, T) -> Void
    ) -> HACancellable {
        sentRequests.append(request.request)
        initiated(.failure(.internal(debugDescription: "Subscriptions not mocked")))
        return HANoopCancellable()
    }
}
