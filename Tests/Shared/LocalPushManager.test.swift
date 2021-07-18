import HAKit
import PromiseKit
@testable import Shared
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

        api = FakeHomeAssistantAPI(
            tokenInfo: .init(
                accessToken: "atoken",
                refreshToken: "refreshtoken",
                expiration: Date()
            )
        )
        Current.api = .value(api)

        apiConnection = HAMockConnection()
        Current.apiConnection = apiConnection

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

    private func setUpManager(webhookID: String?) {
        if let webhookID = webhookID {
            Current.settingsStore.connectionInfo = .init(
                externalURL: URL(string: "http://example.com")!,
                internalURL: nil,
                cloudhookURL: nil,
                remoteUIURL: nil,
                webhookID: webhookID,
                webhookSecret: "webhooksecret",
                internalSSIDs: nil,
                internalHardwareAddresses: nil,
                isLocalPushEnabled: true
            )
        } else {
            Current.settingsStore.connectionInfo = nil
        }

        manager = LocalPushManager()
        manager.add = { [weak self] request in
            let (promise, resolver) = Promise<Void>.pending()
            self?.added.append((request, resolver))
            DispatchQueue.main.async { self?.addedChanged?() }
            return promise
        }
    }

    private func fireConnectionChange() {
        NotificationCenter.default.post(
            name: SettingsStore.connectionInfoDidChange,
            object: nil,
            userInfo: nil
        )
        let expectation = self.expectation(description: "loop")
        DispatchQueue.main.async {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10)
    }

    func testStateInitialUnavailable() {
        setUpManager(webhookID: nil)
        XCTAssertEqual(manager.state, .unavailable)
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
        setUpManager(webhookID: "webhook1")

        let sub1 = try XCTUnwrap(apiConnection.pendingSubscriptions.first)
        XCTAssertEqual(sub1.request.type, "mobile_app/push_notification_channel")
        XCTAssertEqual(sub1.request.data["webhook_id"] as? String, "webhook1")

        sub1.initiated(.success(.empty))

        apiConnection.pendingSubscriptions.removeAll()
        fireConnectionChange()
        XCTAssertTrue(apiConnection.pendingSubscriptions.isEmpty, "same id")

        // change webhookID
        Current.settingsStore.connectionInfo?.webhookID = "webhook2"
        fireConnectionChange()

        XCTAssertTrue(sub1.cancellable.wasCancelled)

        let sub2 = try XCTUnwrap(apiConnection.pendingSubscriptions.first)
        XCTAssertEqual(sub2.request.type, "mobile_app/push_notification_channel")
        XCTAssertEqual(sub2.request.data["webhook_id"] as? String, "webhook2")

        // fail the subscription
        sub2.initiated(.failure(.internal(debugDescription: "unit-test")))
        fireConnectionChange()

        // now succeed it (e.g. reconnect happened)
        sub2.initiated(.success(.empty))

        // kill off the connection info
        apiConnection.pendingSubscriptions.removeAll()
        Current.settingsStore.connectionInfo = nil
        fireConnectionChange()

        XCTAssertTrue(sub2.cancellable.wasCancelled)
    }

    func testInvalidate() throws {
        setUpManager(webhookID: "webhook1")
        let sub = try XCTUnwrap(apiConnection.pendingSubscriptions.first)
        manager.invalidate()
        XCTAssertTrue(sub.cancellable.wasCancelled)
    }

    func testNoSubscriptionAtStart() throws {
        setUpManager(webhookID: nil)
        XCTAssertTrue(apiConnection.pendingSubscriptions.isEmpty)
    }

    func testEventSuccessfullyAdded() throws {
        setUpManager(webhookID: "webhook1")

        let sub = try XCTUnwrap(apiConnection.pendingSubscriptions.first)
        sub.handler(sub.cancellable, .dictionary([
            "message": "test_message",
            "data": [
                "tag": "test_tag",
            ],
        ]))

        let expectation1 = expectation(description: "contentRequestsChanged")
        attachmentManager.contentRequestsChanged = {
            expectation1.fulfill()
        }

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
    }

    func testEventAttachmentFails() throws {
        setUpManager(webhookID: "webhook1")

        // weird scenario, not super possible, but maybe during logout
        Current.resetAPI()

        let expectation1 = expectation(description: "addedChanged")
        addedChanged = {
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

        let final = try XCTUnwrap(added.first)
        XCTAssertEqual(final.0.content.body, "test_message")
        XCTAssertEqual(final.0.identifier, "test_tag")
        final.1.fulfill(())
    }

    func testEventAddFails() throws {
        setUpManager(webhookID: "webhook1")

        let sub = try XCTUnwrap(apiConnection.pendingSubscriptions.first)
        sub.handler(sub.cancellable, .dictionary([
            "message": "test_message",
            "data": [
                "tag": "test_tag",
            ],
        ]))

        let expectation1 = expectation(description: "contentRequestsChanged")
        attachmentManager.contentRequestsChanged = {
            expectation1.fulfill()
        }

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
