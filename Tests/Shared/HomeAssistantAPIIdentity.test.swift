import HAKit
import PromiseKit
@testable import Shared
import UIKit
import XCTest

final class HomeAssistantAPIIdentityTests: XCTestCase {
    private var originalDiskCache: DiskCache!
    private var fakeDiskCache: FakeDiskCache!

    override func setUp() {
        super.setUp()
        originalDiskCache = Current.diskCache
        fakeDiskCache = FakeDiskCache()
        Current.diskCache = fakeDiskCache
    }

    override func tearDown() {
        Current.diskCache = originalDiskCache
        ServerFixture.reset()
        super.tearDown()
    }

    func testCurrentUserUsesWebSocketEndpoint() {
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

        guard case let .webSocket(command) = connection.sentRequests[0].type else {
            XCTFail("Expected WebSocket request")
            return
        }

        XCTAssertEqual(command, "auth/current_user")
    }

    func testProfilePictureURLUsesWebSocketCurrentUserAndRestStates() {
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

        guard case let .webSocket(firstCommand) = connection.sentRequests[0].type else {
            XCTFail("Expected first request to use WebSocket")
            return
        }

        XCTAssertEqual(firstCommand, "auth/current_user")

        guard case let .rest(secondMethod, secondCommand) = connection.sentRequests[1].type else {
            XCTFail("Expected second request to use REST")
            return
        }

        XCTAssertEqual(secondMethod, .get)
        XCTAssertEqual(secondCommand, "states")
    }

    func testProfilePictureURLRejectsExternalEntityPictureURL() {
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
                    "entity_picture": "https://attacker.example.com/avatar.png",
                ],
                "context": [
                    "id": "context-id",
                ],
            ]),
        ])
        api.connection = connection

        let expectation = expectation(description: "profile picture URL")

        api.profilePictureURL { url in
            XCTAssertNil(url)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(connection.sentRequests.count, 2)
    }

    func testProfilePictureFallsBackToCacheWhenStatesUnavailable() throws {
        let api = HomeAssistantAPI(server: ServerFixture.withRemoteConnection)
        api.connection = FakeHAConnection()

        fakeDiskCache.storage[api.profilePictureCacheKey] = makePNGData()

        let user = try makeUser()
        let expectation = expectation(description: "profile picture")
        var images = [UIImage?]()

        api.profilePicture(for: user) { image in
            images.append(image)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(images.count, 1)
        XCTAssertNotNil(images[0])
        XCTAssertTrue(fakeDiskCache.deletedKeys.isEmpty)
    }

    func testProfilePictureDeliversCacheThenClearsWhenPictureMissing() throws {
        let api = HomeAssistantAPI(server: ServerFixture.withRemoteConnection)
        let connection = FakeHAConnection()
        connection.mockResponses["states"] = .array([
            .dictionary([
                "entity_id": "person.cepresso",
                "state": "home",
                "last_changed": "2026-04-23T10:00:00Z",
                "last_updated": "2026-04-23T10:00:00Z",
                "attributes": [
                    "user_id": "user-id",
                ],
                "context": [
                    "id": "context-id",
                ],
            ]),
        ])
        api.connection = connection

        fakeDiskCache.storage[api.profilePictureCacheKey] = makePNGData()

        let user = try makeUser()
        let expectation = expectation(description: "profile picture")
        expectation.expectedFulfillmentCount = 2
        var images = [UIImage?]()

        api.profilePicture(for: user) { image in
            images.append(image)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(images.count, 2)
        XCTAssertNotNil(images[0])
        XCTAssertNil(images[1])
        XCTAssertEqual(fakeDiskCache.deletedKeys, [api.profilePictureCacheKey])
    }

    func testProfilePictureKeepsCacheWhenPersonEntityNotFound() throws {
        let api = HomeAssistantAPI(server: ServerFixture.withRemoteConnection)
        let connection = FakeHAConnection()
        connection.mockResponses["states"] = .array([
            .dictionary([
                "entity_id": "person.someone_else",
                "state": "home",
                "last_changed": "2026-04-23T10:00:00Z",
                "last_updated": "2026-04-23T10:00:00Z",
                "attributes": [
                    "user_id": "another-user-id",
                ],
                "context": [
                    "id": "context-id",
                ],
            ]),
        ])
        api.connection = connection

        fakeDiskCache.storage[api.profilePictureCacheKey] = makePNGData()

        let user = try makeUser()
        let expectation = expectation(description: "profile picture")
        var images = [UIImage?]()

        api.profilePicture(for: user) { image in
            images.append(image)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(images.count, 1)
        XCTAssertNotNil(images[0])
        XCTAssertTrue(fakeDiskCache.deletedKeys.isEmpty)
    }

    func testProfilePictureWithoutCacheReturnsNilWhenStatesUnavailable() throws {
        let api = HomeAssistantAPI(server: ServerFixture.withRemoteConnection)
        api.connection = FakeHAConnection()

        let user = try makeUser()
        let expectation = expectation(description: "profile picture")

        api.profilePicture(for: user) { image in
            XCTAssertNil(image)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
    }

    private func makeUser() throws -> HAResponseCurrentUser {
        try HAResponseCurrentUser(data: .dictionary([
            "id": "user-id",
            "name": "cepresso",
            "is_owner": false,
            "is_admin": true,
            "credentials": [],
            "mfa_modules": [],
        ]))
    }

    private func makePNGData() -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1))
        let image = renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        guard let data = image.pngData() else {
            preconditionFailure("Unable to encode test image")
        }
        return data
    }

    private final class FakeDiskCache: DiskCache {
        enum FakeDiskCacheError: Error {
            case missing
        }

        var storage = [String: Any]()
        private(set) var deletedKeys = [String]()

        func value<T: Codable>(for key: String) -> Promise<T> {
            if let value = storage[key] as? T {
                return .value(value)
            }
            return Promise(error: FakeDiskCacheError.missing)
        }

        func set(_ value: some Codable, for key: String) -> Promise<Void> {
            storage[key] = value
            return .value(())
        }

        func delete(for key: String) -> Promise<Void> {
            storage[key] = nil
            deletedKeys.append(key)
            return .value(())
        }
    }

    func testCertificateAwareSessionAttachesDelegateWithoutClientCertificate() {
        let server = makeServer(clientCertificate: nil)
        XCTAssertNil(server.info.connection.clientCertificate)
        XCTAssertFalse(server.info.connection.securityExceptions.hasExceptions)

        let session = HomeAssistantAPI.makeCertificateAwareURLSession(server: server)
        defer { session.finishTasksAndInvalidate() }

        XCTAssertTrue(session.delegate is HAURLSessionDelegate)
    }

    func testCertificateAwareSessionAttachesDelegateWithClientCertificate() {
        let server = makeServer(clientCertificate: ClientCertificate(
            keychainIdentifier: "com.ha-ios.mtls.identity.test",
            displayName: "Test"
        ))

        let session = HomeAssistantAPI.makeCertificateAwareURLSession(server: server)
        defer { session.finishTasksAndInvalidate() }

        XCTAssertTrue(session.delegate is HAURLSessionDelegate)
    }

    private func makeServer(clientCertificate: ClientCertificate?) -> Server {
        var info = ServerInfo(
            name: "Certificate Server",
            connection: .init(
                externalURL: URL(string: "https://external.example.com"),
                internalURL: nil,
                cloudhookURL: nil,
                remoteUIURL: nil,
                webhookID: "webhook-id",
                webhookSecret: nil,
                internalSSIDs: nil,
                internalHardwareAddresses: nil,
                isLocalPushEnabled: false,
                securityExceptions: .init(exceptions: []),
                connectionAccessSecurityLevel: .undefined,
                clientCertificate: clientCertificate
            ),
            token: .init(accessToken: "access-token", refreshToken: "refresh-token", expiration: Date()),
            version: "2026.4.1"
        )
        return Server(identifier: "certificate-test", getter: { info }, setter: { newInfo in
            info = newInfo
            return true
        })
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
        completion: @escaping (Swift.Result<T, HAError>) -> Void
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
