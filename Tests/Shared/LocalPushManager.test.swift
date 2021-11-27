import HAKit
import PromiseKit
@testable import Shared
import Version
import XCTest

class LocalPushManagerTests: XCTestCase {
    private var manager: LocalPushManager!
    private var api: FakeHomeAssistantAPI!
    private var apiConnection: HAMockConnection!
    private var attachmentManager: FakeNotificationAttachmentManager!

    private var added: [(UNNotificationRequest, Resolver<Void>)] = []
    private var addedChanged: (() -> Void)?

    override func setUp() {
        super.setUp()

        attachmentManager = FakeNotificationAttachmentManager()
        Current.notificationAttachmentManager = attachmentManager

        let server: Server

        let fakeServers = FakeServerManager()
        Current.servers = fakeServers

        server = fakeServers.addFake()

        api = FakeHomeAssistantAPI(server: server)
        apiConnection = HAMockConnection()
        api.connection = apiConnection

        Current.cachedApis[server.identifier] = api

        added = []
    }

    override func tearDown() {
        super.tearDown()

        weak var weakManager = manager
        manager = nil
        XCTAssertNil(weakManager)

        for sub in apiConnection.pendingSubscriptions {
            XCTAssertTrue(sub.cancellable.wasCancelled)
        }
    }

    private func setUpManager(webhookID: String, version: Version? = nil) {
        api.server.info.connection.webhookID = webhookID
        if let version = version {
            api.server.info.version = version
        }

        manager = LocalPushManager(server: api.server)
        manager.add = { [weak self] request in
            let (promise, resolver) = Promise<Void>.pending()
            self?.added.append((request, resolver))
            DispatchQueue.main.async { self?.addedChanged?() }
            return promise
        }
    }

    private func fireConnectionChange() {
        api.server.info.connection.internalHardwareAddresses = [UUID().uuidString]
        let expectation = self.expectation(description: "loop")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10)
    }

    func testStateInitialSuccessful() throws {
        setUpManager(webhookID: "webhook1")
        XCTAssertEqual(manager.state, .establishing)

        let sub = try XCTUnwrap(apiConnection.pendingSubscriptions.first)
        sub.initiated(.success(.empty))
        XCTAssertEqual(manager.state, .available(received: 0))

        sub.handler(sub.cancellable, .dictionary([
            "message": "test_message",
        ]))
        XCTAssertEqual(manager.state, .available(received: 1))

        sub.handler(sub.cancellable, .dictionary([
            "message": "test_message",
        ]))
        XCTAssertEqual(manager.state, .available(received: 2))
    }

    func testStateInitialFailure() throws {
        setUpManager(webhookID: "webhook1")
        XCTAssertEqual(manager.state, .establishing)

        let sub = try XCTUnwrap(apiConnection.pendingSubscriptions.first)
        sub.initiated(.failure(.internal(debugDescription: "unit-test")))
        XCTAssertEqual(manager.state, .unavailable)

        // pretend like a future connection made it work
        sub.initiated(.success(.empty))
        XCTAssertEqual(manager.state, .available(received: 0))

        sub.handler(sub.cancellable, .dictionary([
            "message": "test_message",
        ]))
        XCTAssertEqual(manager.state, .available(received: 1))
    }

    func testSubscriptionAtStart() throws {
        setUpManager(webhookID: "webhook1", version: .init(major: 2021, minor: 9))

        let sub1 = try XCTUnwrap(apiConnection.pendingSubscriptions.first)
        XCTAssertEqual(sub1.request.type, "mobile_app/push_notification_channel")
        XCTAssertEqual(sub1.request.data["webhook_id"] as? String, "webhook1")
        XCTAssertNil(sub1.request.data["support_confirm"])

        sub1.initiated(.success(.empty))

        apiConnection.pendingSubscriptions.removeAll()
        fireConnectionChange()
        XCTAssertTrue(apiConnection.pendingSubscriptions.isEmpty, "same id")

        api.server.info.version = .init(major: 2021, minor: 10)

        // change webhookID
        api.server.info.connection.webhookID = "webhook2"
        fireConnectionChange()

        XCTAssertTrue(sub1.cancellable.wasCancelled)

        let sub2 = try XCTUnwrap(apiConnection.pendingSubscriptions.first)
        XCTAssertEqual(sub2.request.type, "mobile_app/push_notification_channel")
        XCTAssertEqual(sub2.request.data["webhook_id"] as? String, "webhook2")
        XCTAssertEqual(sub2.request.data["support_confirm"] as? Bool, true)

        // fail the subscription
        sub2.initiated(.failure(.internal(debugDescription: "unit-test")))
        fireConnectionChange()

        // now succeed it (e.g. reconnect happened)
        sub2.initiated(.success(.empty))
    }

    func testInvalidate() throws {
        setUpManager(webhookID: "webhook1")
        let sub = try XCTUnwrap(apiConnection.pendingSubscriptions.first)
        manager.invalidate()
        XCTAssertTrue(sub.cancellable.wasCancelled)
    }

    func testEventSuccessfullyAddedWithoutConfirmId() throws {
        setUpManager(webhookID: "webhook1")

        let expectation1 = expectation(description: "contentRequestsChanged")
        attachmentManager.contentRequestsChanged = {
            expectation1.fulfill()
        }

        let sub = try XCTUnwrap(apiConnection.pendingSubscriptions.first)
        sub.handler(sub.cancellable, .dictionary([
            "message": "test_message",
            "data": [
                "tag": "test_tag",
            ],
        ]))

        waitForExpectations(timeout: 10.0)

        let req = try XCTUnwrap(attachmentManager.contentRequests.first)
        XCTAssertEqual(req.0.body, "test_message")
        req.1(with(UNMutableNotificationContent()) {
            $0.body = "test_message_modified"
        })

        let expectation2 = expectation(description: "addedChanged")
        addedChanged = {
            expectation2.fulfill()
        }

        waitForExpectations(timeout: 10.0)

        let final = try XCTUnwrap(added.first)
        XCTAssertEqual(final.0.content.body, "test_message_modified")
        XCTAssertEqual(final.0.identifier, "test_tag")
        final.1.fulfill(())

        XCTAssertFalse(
            apiConnection.pendingRequests
                .contains(where: { $0.request.type == "mobile_app/push_notification_confirm" })
        )
    }

    func testEventSuccessfullyAddedWithConfirmIdSuccessfullyConfirm() throws {
        setUpManager(webhookID: "webhook1")

        let expectation1 = expectation(description: "contentRequestsChanged")
        attachmentManager.contentRequestsChanged = {
            expectation1.fulfill()
        }

        let sub = try XCTUnwrap(apiConnection.pendingSubscriptions.first)
        sub.handler(sub.cancellable, .dictionary([
            "message": "test_message",
            "hass_confirm_id": "test_confirm_id",
            "data": [
                "tag": "test_tag",
            ],
        ]))

        waitForExpectations(timeout: 10.0)

        let req = try XCTUnwrap(attachmentManager.contentRequests.first)
        XCTAssertEqual(req.0.body, "test_message")
        req.1(with(UNMutableNotificationContent()) {
            $0.body = "test_message_modified"
        })

        let expectation2 = expectation(description: "addedChanged")
        addedChanged = {
            expectation2.fulfill()
        }

        waitForExpectations(timeout: 10.0)

        let final = try XCTUnwrap(added.first)
        XCTAssertEqual(final.0.content.body, "test_message_modified")
        XCTAssertEqual(final.0.identifier, "test_tag")
        final.1.fulfill(())

        let pendingRequest = try XCTUnwrap(
            apiConnection.pendingRequests
                .first(where: { $0.request.type == "mobile_app/push_notification_confirm" })
        )
        XCTAssertEqual(pendingRequest.request.data["webhook_id"] as? String, "webhook1")
        XCTAssertEqual(pendingRequest.request.data["confirm_id"] as? String, "test_confirm_id")

        // just making sure this doesn't have a runtime problem
        pendingRequest.completion(.success(.empty))
    }

    func testEventSuccessfullyAddedWithConfirmIdFailsToConfirm() throws {
        setUpManager(webhookID: "webhook1")

        let expectation1 = expectation(description: "contentRequestsChanged")
        attachmentManager.contentRequestsChanged = {
            expectation1.fulfill()
        }

        let sub = try XCTUnwrap(apiConnection.pendingSubscriptions.first)
        sub.handler(sub.cancellable, .dictionary([
            "message": "test_message",
            "hass_confirm_id": "test_confirm_id",
            "data": [
                "tag": "test_tag",
            ],
        ]))

        waitForExpectations(timeout: 10.0)

        let req = try XCTUnwrap(attachmentManager.contentRequests.first)
        XCTAssertEqual(req.0.body, "test_message")
        req.1(with(UNMutableNotificationContent()) {
            $0.body = "test_message_modified"
        })

        let expectation2 = expectation(description: "addedChanged")
        addedChanged = {
            expectation2.fulfill()
        }

        waitForExpectations(timeout: 10.0)

        let final = try XCTUnwrap(added.first)
        XCTAssertEqual(final.0.content.body, "test_message_modified")
        XCTAssertEqual(final.0.identifier, "test_tag")
        final.1.fulfill(())

        let pendingRequest = try XCTUnwrap(
            apiConnection.pendingRequests
                .first(where: { $0.request.type == "mobile_app/push_notification_confirm" })
        )
        XCTAssertEqual(pendingRequest.request.data["webhook_id"] as? String, "webhook1")
        XCTAssertEqual(pendingRequest.request.data["confirm_id"] as? String, "test_confirm_id")

        // just making sure this doesn't have a runtime problem
        pendingRequest.completion(.failure(.internal(debugDescription: "unit-test")))
    }

    func testEventAddFails() throws {
        setUpManager(webhookID: "webhook1")

        let expectation1 = expectation(description: "contentRequestsChanged")
        attachmentManager.contentRequestsChanged = {
            expectation1.fulfill()
        }

        let sub = try XCTUnwrap(apiConnection.pendingSubscriptions.first)
        sub.handler(sub.cancellable, .dictionary([
            "message": "test_message",
            "data": [
                "tag": "test_tag",
            ],
        ]))

        waitForExpectations(timeout: 10.0)

        let req = try XCTUnwrap(attachmentManager.contentRequests.first)
        XCTAssertEqual(req.0.body, "test_message")
        req.1(with(UNMutableNotificationContent()) {
            $0.body = "test_message_modified"
        })

        let expectation2 = expectation(description: "addedChanged")
        addedChanged = {
            expectation2.fulfill()
        }

        waitForExpectations(timeout: 10.0)

        let final = try XCTUnwrap(added.first)
        XCTAssertEqual(final.0.content.body, "test_message_modified")
        XCTAssertEqual(final.0.identifier, "test_tag")
        enum TestError: Error { case any }
        final.1.reject(TestError.any)
    }
}

private class FakeNotificationAttachmentManager: NotificationAttachmentManager {
    var contentRequests: [(UNNotificationContent, (UNNotificationContent) -> Void)] = []
    var contentRequestsChanged: (() -> Void)?

    func content(
        from originalContent: UNNotificationContent,
        api: HomeAssistantAPI
    ) -> Guarantee<UNNotificationContent> {
        let (guarantee, seal) = Guarantee<UNNotificationContent>.pending()
        contentRequests.append((originalContent, seal))
        DispatchQueue.main.async { [contentRequestsChanged] in
            contentRequestsChanged?()
        }
        return guarantee
    }

    func downloadAttachment(from originalContent: UNNotificationContent, api: HomeAssistantAPI) -> Promise<URL> {
        fatalError()
    }
}

private class FakeHomeAssistantAPI: HomeAssistantAPI {}
