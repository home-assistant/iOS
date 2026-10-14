import HAKit
import HAKit_Mocks
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

    private func setUpManager(
        webhookID: String,
        version: Version? = nil,
        notificationCommunicationDecorator: NotificationCommunicationDecorator =
            NotificationCommunicationDecoratorImpl()
    ) {
        api.server.info.connection.webhookID = webhookID
        if let version {
            api.server.info.version = version
        }

        manager = LocalPushManager(
            server: api.server,
            notificationCommunicationDecorator: notificationCommunicationDecorator
        )
        manager.add = { [weak self] request in
            let (promise, resolver) = Promise<Void>.pending()
            self?.added.append((request, resolver))
            DispatchQueue.main.async { self?.addedChanged?() }
            return promise
        }
    }

    private func fireConnectionChange() {
        api.server.info.connection.internalHardwareAddresses = [UUID().uuidString]
        let expectation = expectation(description: "loop")
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

        let expectation3 = expectation(description: "run loop")
        DispatchQueue.main.async(execute: expectation3.fulfill)
        waitForExpectations(timeout: 10.0)

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

        let expectation3 = expectation(description: "run loop")
        DispatchQueue.main.async(execute: expectation3.fulfill)
        waitForExpectations(timeout: 10.0)

        let pendingRequest = try XCTUnwrap(
            apiConnection.pendingRequests
                .first(where: { $0.request.type == "mobile_app/push_notification_confirm" })
        )
        XCTAssertEqual(pendingRequest.request.data["webhook_id"] as? String, "webhook1")
        XCTAssertEqual(pendingRequest.request.data["confirm_id"] as? String, "test_confirm_id")

        // just making sure this doesn't have a runtime problem
        pendingRequest.completion(.failure(.internal(debugDescription: "unit-test")))
    }

    func testEventAddFailsWithoutConfirmId() throws {
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

    func testEventAddFailsWithConfirmId() throws {
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
            "hass_confirm_id": "test_confirm_id",
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

        let expectation3 = expectation(description: "run loop")
        DispatchQueue.main.async(execute: expectation3.fulfill)
        waitForExpectations(timeout: 10.0)

        XCTAssertFalse(
            apiConnection.pendingRequests
                .contains(where: { $0.request.type == "mobile_app/push_notification_confirm" })
        )
    }

    func testEventCommunicationDecoratorInvoked() throws {
        class SpyDecorator: NotificationCommunicationDecorator {
            var decorateCalled = false
            var apiUsed: HomeAssistantAPI?
            let decoratedBody = "decorated_body"

            func decorate(
                content: UNNotificationContent,
                sender: NotificationSenderInfo,
                api: HomeAssistantAPI?
            ) async -> UNNotificationContent {
                decorateCalled = true
                apiUsed = api
                let decoratedContent = UNMutableNotificationContent()
                decoratedContent.body = decoratedBody
                return decoratedContent
            }
        }

        let spy = SpyDecorator()

        setUpManager(webhookID: "webhook1", notificationCommunicationDecorator: spy)

        let expectation1 = expectation(description: "contentRequestsChanged")
        attachmentManager.contentRequestsChanged = {
            expectation1.fulfill()
        }

        let sub = try XCTUnwrap(apiConnection.pendingSubscriptions.first)
        sub.handler(sub.cancellable, .dictionary([
            "message": "test_message",
            "notification_icon": "mdi:dishwasher",
            "data": [
                "tag": "test_tag",
            ],
        ]))

        waitForExpectations(timeout: 10.0)

        let req = try XCTUnwrap(attachmentManager.contentRequests.first)
        req.1(with(UNMutableNotificationContent()) {
            $0.body = "test_message_modified"
            $0.title = "test_title"
            $0.userInfo = [
                "notification_icon": "mdi:dishwasher",
            ]
        })

        let expectation2 = expectation(description: "addedChanged")
        addedChanged = {
            expectation2.fulfill()
        }

        waitForExpectations(timeout: 10.0)

        XCTAssertTrue(spy.decorateCalled)
        XCTAssertIdentical(spy.apiUsed, api)
        XCTAssertEqual(added.last?.0.content.body, spy.decoratedBody)
    }

    func testSilentLiveActivityCommandSuppressesBannerAndConfirmsImmediately() throws {
        setUpManager(webhookID: "webhook1")

        let sub = try XCTUnwrap(apiConnection.pendingSubscriptions.first)
        sub.handler(sub.cancellable, .dictionary([
            "message": "test_message",
            "hass_confirm_id": "test_confirm_id",
            "data": [
                "live_update": true,
                "tag": "test_tag",
                "silent": true,
            ],
        ]))

        let runLoop = expectation(description: "run loop")
        DispatchQueue.main.async(execute: runLoop.fulfill)
        waitForExpectations(timeout: 10.0)

        XCTAssertTrue(attachmentManager.contentRequests.isEmpty)
        XCTAssertTrue(added.isEmpty)
        let confirm = try XCTUnwrap(
            apiConnection.pendingRequests
                .first(where: { $0.request.type == "mobile_app/push_notification_confirm" })
        )
        XCTAssertEqual(confirm.request.data["confirm_id"] as? String, "test_confirm_id")
        XCTAssertEqual(confirm.request.data["webhook_id"] as? String, "webhook1")
    }

    func testNonSilentLiveActivityCommandSuppressesBannerAndConfirmsImmediately() throws {
        // A live_update without `silent: true` must behave like the silent case: only update the
        // Live Activity, never present a standalone banner, and confirm receipt right away so the
        // server keeps the channel open even when the app cannot drain the hand-off yet.
        setUpManager(webhookID: "webhook1")

        let sub = try XCTUnwrap(apiConnection.pendingSubscriptions.first)
        sub.handler(sub.cancellable, .dictionary([
            "message": "test_message",
            "hass_confirm_id": "test_confirm_id",
            "data": [
                "live_update": true,
                "tag": "test_tag",
            ],
        ]))

        let runLoop = expectation(description: "run loop")
        DispatchQueue.main.async(execute: runLoop.fulfill)
        waitForExpectations(timeout: 10.0)

        XCTAssertTrue(attachmentManager.contentRequests.isEmpty)
        XCTAssertTrue(added.isEmpty)
        let confirm = try XCTUnwrap(
            apiConnection.pendingRequests
                .first(where: { $0.request.type == "mobile_app/push_notification_confirm" })
        )
        XCTAssertEqual(confirm.request.data["confirm_id"] as? String, "test_confirm_id")
    }

    func testLiveActivityCommandWithoutConfirmIdDoesNotConfirm() throws {
        setUpManager(webhookID: "webhook1")

        let sub = try XCTUnwrap(apiConnection.pendingSubscriptions.first)
        sub.handler(sub.cancellable, .dictionary([
            "message": "test_message",
            "data": [
                "live_update": true,
                "tag": "test_tag",
            ],
        ]))

        let runLoop = expectation(description: "run loop")
        DispatchQueue.main.async(execute: runLoop.fulfill)
        waitForExpectations(timeout: 10.0)

        XCTAssertTrue(added.isEmpty)
        XCTAssertFalse(
            apiConnection.pendingRequests
                .contains(where: { $0.request.type == "mobile_app/push_notification_confirm" })
        )
    }

    func testLiveActivityLocalPushPromotesStylingFields() throws {
        // Local push delivers a flat {message, data} payload; the parser must promote the
        // live-activity styling fields out of `data` into `homeassistant` so they reach the
        // content state. Regression test: background_color / text_color / progress_bar_color
        // were previously dropped, so updates reset the lock-screen background to black and
        // later updates could never re-color it.
        let event = try LocalPushEvent(data: .dictionary([
            "message": "Washing",
            "data": [
                "live_update": true,
                "tag": "laundry",
                "notification_icon_color": "#FF0000",
                "background_color": "#101820",
                "text_color": "#FFFFFF",
                "progress_bar_color": "#03A9F4",
                "progress_bar_direction": "decreasing",
                "relevance_score": 0.7,
            ],
        ]))

        let ha = try XCTUnwrap(event.contentWithoutServer.userInfo["homeassistant"] as? [String: Any])
        XCTAssertEqual(ha["live_update"] as? Bool, true)
        XCTAssertEqual(ha["background_color"] as? String, "#101820")
        XCTAssertEqual(ha["text_color"] as? String, "#FFFFFF")
        XCTAssertEqual(ha["progress_bar_color"] as? String, "#03A9F4")
        XCTAssertEqual(ha["progress_bar_direction"] as? String, "decreasing")
        XCTAssertEqual(ha["notification_icon_color"] as? String, "#FF0000")
        XCTAssertEqual(ha["relevance_score"] as? Double, 0.7)
    }

    func testNonLiveActivityCommandSuppressesBannerButConfirms() throws {
        setUpManager(webhookID: "webhook1")

        let sub = try XCTUnwrap(apiConnection.pendingSubscriptions.first)
        sub.handler(sub.cancellable, .dictionary([
            "message": "clear_notification",
            "hass_confirm_id": "test_confirm_id",
            "data": [
                "tag": "test_tag",
            ],
        ]))

        let runLoop = expectation(description: "run loop")
        DispatchQueue.main.async(execute: runLoop.fulfill)
        waitForExpectations(timeout: 10.0)

        XCTAssertTrue(attachmentManager.contentRequests.isEmpty)
        XCTAssertTrue(added.isEmpty)
        let confirm = try XCTUnwrap(
            apiConnection.pendingRequests
                .first(where: { $0.request.type == "mobile_app/push_notification_confirm" })
        )
        XCTAssertEqual(confirm.request.data["confirm_id"] as? String, "test_confirm_id")
    }

    func testSubscriptionRetriesIndefinitelyAcrossReconnects() throws {
        setUpManager(webhookID: "webhook1")
        let sub = try XCTUnwrap(apiConnection.pendingSubscriptions.first)
        XCTAssertNil(sub.request.retryDuration)
        XCTAssertTrue(sub.request.shouldRetry)
    }

    func testConnectionDropMarksUnavailableAndKeepsCountAfterResubscribe() throws {
        setUpManager(webhookID: "webhook1")
        let sub = try XCTUnwrap(apiConnection.pendingSubscriptions.first)
        sub.initiated(.success(.empty))
        sub.handler(sub.cancellable, .dictionary(["message": "one"]))
        sub.handler(sub.cancellable, .dictionary(["message": "two"]))
        XCTAssertEqual(manager.state, .available(received: 2))

        apiConnection.setState(.disconnected(reason: .waitingToReconnect(
            lastError: nil,
            atLatest: Date(),
            retryCount: 1
        )))
        XCTAssertEqual(manager.state, .unavailable)

        apiConnection.setState(.ready(version: "2026.10.1"))
        XCTAssertEqual(manager.state, .unavailable)

        sub.initiated(.success(.empty))
        XCTAssertEqual(manager.state, .available(received: 2))

        sub.handler(sub.cancellable, .dictionary(["message": "three"]))
        XCTAssertEqual(manager.state, .available(received: 3))
    }

    func testConnectionDropBeforeSubscribedDoesNotChangeState() {
        setUpManager(webhookID: "webhook1")
        XCTAssertEqual(manager.state, .establishing)

        apiConnection.setState(.disconnected(reason: .disconnected))
        XCTAssertEqual(manager.state, .establishing)
    }

    func testAvailabilityTransitionsReportEventsAndDebugNotification() throws {
        var events = [ClientEvent]()
        let originalStore = Current.clientEventStore
        Current.clientEventStore = MockClientEventStore(onAddEvent: { events.append($0) })
        defer { Current.clientEventStore = originalStore }

        let dispatcher = FakeLocalNotificationDispatcher()
        let originalDispatcher = Current.notificationDispatcher
        Current.notificationDispatcher = dispatcher
        defer { Current.notificationDispatcher = originalDispatcher }

        setUpManager(webhookID: "webhook1")
        let sub = try XCTUnwrap(apiConnection.pendingSubscriptions.first)
        XCTAssertTrue(events.isEmpty)
        XCTAssertTrue(dispatcher.sent.isEmpty)

        sub.initiated(.success(.empty))
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(dispatcher.sent.count, 1)
        XCTAssertEqual(dispatcher.sent.last?.id, .localPushStateChanged)
        XCTAssertEqual(dispatcher.sent.last?.title, L10n.LocalPush.StateNotification.Connected.title)

        sub.handler(sub.cancellable, .dictionary(["message": "one"]))
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(dispatcher.sent.count, 1)

        apiConnection.setState(.disconnected(reason: .waitingToReconnect(
            lastError: HAError.internal(debugDescription: "boom"),
            atLatest: Date(),
            retryCount: 2
        )))
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events.last?.type, .notification)
        let reason = try XCTUnwrap(events.last?.jsonPayload["reason"]?.value as? String)
        XCTAssertTrue(reason.hasSuffix("(retry 2)"), reason)
        XCTAssertEqual(events.last?.jsonPayload["received"]?.value as? Int, 1)
        XCTAssertEqual(dispatcher.sent.count, 2)
        XCTAssertEqual(dispatcher.sent.last?.title, L10n.LocalPush.StateNotification.Disconnected.title)

        sub.initiated(.failure(.internal(debugDescription: "still down")))
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(dispatcher.sent.count, 2)

        sub.initiated(.success(.empty))
        XCTAssertEqual(events.count, 3)
        XCTAssertEqual(dispatcher.sent.count, 3)
        XCTAssertEqual(dispatcher.sent.last?.title, L10n.LocalPush.StateNotification.Connected.title)

        apiConnection.setState(.disconnected(reason: .rejected))
        XCTAssertEqual(events.count, 4)
        XCTAssertEqual(events.last?.jsonPayload["reason"]?.value as? String, "connection rejected")
        XCTAssertEqual(dispatcher.sent.count, 4)
    }

    func testInvalidateStopsObservingConnectionState() throws {
        setUpManager(webhookID: "webhook1")
        let sub = try XCTUnwrap(apiConnection.pendingSubscriptions.first)
        sub.initiated(.success(.empty))
        XCTAssertEqual(manager.state, .available(received: 0))

        manager.invalidate()
        apiConnection.setState(.disconnected(reason: .disconnected))
        XCTAssertEqual(manager.state, .available(received: 0))
    }

    func testPushProviderConfigurationDecodeRoundTripsAndCompares() throws {
        let server = api.server
        let configurations = [
            PushProviderConfiguration(
                serverIdentifier: server.identifier,
                settingsKey: PushProviderConfiguration.defaultSettingsKey(for: server)
            ),
        ]
        let data = try JSONEncoder().encode(configurations)

        XCTAssertEqual(PushProviderConfiguration.decode(from: data), configurations)
        XCTAssertNil(PushProviderConfiguration.decode(from: nil))
        XCTAssertNil(PushProviderConfiguration.decode(from: Data("not json".utf8)))

        let other = PushProviderConfiguration(serverIdentifier: server.identifier, settingsKey: "other")
        XCTAssertNotEqual(PushProviderConfiguration.decode(from: data), [other])
    }

    func testNotifyOnLocalPushStateChangesPreferenceRoundTrips() {
        let original = Current.settingsStore.notifyOnLocalPushStateChanges
        defer { Current.settingsStore.notifyOnLocalPushStateChanges = original }

        Current.settingsStore.notifyOnLocalPushStateChanges = true
        XCTAssertTrue(Current.settingsStore.notifyOnLocalPushStateChanges)
        Current.settingsStore.notifyOnLocalPushStateChanges = false
        XCTAssertFalse(Current.settingsStore.notifyOnLocalPushStateChanges)
    }
}

private final class FakeLocalNotificationDispatcher: LocalNotificationDispatcherProtocol {
    private(set) var sent = [LocalNotificationDispatcher.Notification]()

    func send(_ notification: LocalNotificationDispatcher.Notification) {
        sent.append(notification)
    }

    func reschedule(_ content: UNNotificationContent, after delay: TimeInterval) {}
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
