import Foundation
@testable import Shared
import XCTest

final class HAAPIPersistentEventTests: XCTestCase {
    private final class RecordingWebhookManager: FakeWebhookManager {
        var startResult: Result<Task<Void, Error>, Error> = .failure(WebhookError.requiresMainThread)
        var reconciliationResult: PersistedBackgroundRequestState = .absent
        private(set) var starts = [(
            server: Server,
            request: WebhookRequest,
            identifier: String?,
            timeout: TimeInterval?
        )]()
        private(set) var reconciliations = [String]()

        override func startPersistedBackground(
            identifier: WebhookResponseIdentifier = .unhandled,
            server: Server,
            request: WebhookRequest,
            requestIdentifier: String? = nil,
            requestTimeout: TimeInterval? = nil
        ) -> Result<Task<Void, Error>, Error> {
            starts.append((server, request, requestIdentifier, requestTimeout))
            return startResult
        }

        override func reconcilePersistedBackground(requestIdentifier: String) async -> PersistedBackgroundRequestState {
            reconciliations.append(requestIdentifier)
            return reconciliationResult
        }
    }

    private var previousWebhookManager: WebhookManager!
    private var webhookManager: RecordingWebhookManager!

    override func setUp() {
        super.setUp()
        previousWebhookManager = Current.webhooks
        webhookManager = RecordingWebhookManager()
        Current.webhooks = webhookManager
    }

    override func tearDown() {
        Current.webhooks = previousWebhookManager
        webhookManager = nil
        previousWebhookManager = nil
        super.tearDown()
    }

    @MainActor
    func testImmediatePersistentEventStartsBackgroundTaskDirectly() async throws {
        webhookManager.startResult = .success(Task {})
        let api = HomeAssistantAPI(server: .fake())

        let eventIdentifier = UUID()
        let result = api.startPersistentEvent(
            eventType: "ios.zone_entered",
            eventData: ["zone": "zone.beacon"],
            eventIdentifier: eventIdentifier
        )

        guard case let .success(delivery) = result else {
            return XCTFail("Expected the persisted upload task to start")
        }
        try await delivery.value
        XCTAssertEqual(webhookManager.starts.count, 1)
        let start = try XCTUnwrap(webhookManager.starts.first)
        XCTAssertEqual(start.server.identifier, api.server.identifier)
        XCTAssertEqual(start.identifier, eventIdentifier.uuidString)
        XCTAssertEqual(start.timeout, 30)
        XCTAssertEqual(start.request.type, "fire_event")
        let data = try XCTUnwrap(start.request.data as? [String: Any])
        XCTAssertEqual(data["event_type"] as? String, "ios.zone_entered")
        XCTAssertEqual(data["event_data"] as? [String: String], ["zone": "zone.beacon"])
        XCTAssertEqual(webhookManager.sendCount, 0)
    }

    @MainActor
    func testPersistentEventReturnsSynchronousStartFailure() {
        webhookManager.startResult = .failure(WebhookError.requiresMainThread)
        let api = HomeAssistantAPI(server: .fake())

        let result = api.startPersistentEvent(
            eventType: "ios.zone_entered",
            eventData: [:],
            eventIdentifier: UUID()
        )

        guard case let .failure(error) = result else {
            return XCTFail("Expected the start failure without a delivery task")
        }
        XCTAssertEqual(error as? WebhookError, .requiresMainThread)
        XCTAssertEqual(webhookManager.starts.count, 1)
        XCTAssertEqual(webhookManager.sendCount, 0)
    }

    @MainActor
    func testPersistentEventPropagatesDeliveryFailure() async {
        webhookManager.startResult = .success(Task { throw URLError(.notConnectedToInternet) })
        let api = HomeAssistantAPI(server: .fake())

        let result = api.startPersistentEvent(
            eventType: "ios.zone_exited",
            eventData: [:],
            eventIdentifier: UUID()
        )

        guard case let .success(delivery) = result else {
            return XCTFail("Expected the upload to start before delivery fails")
        }
        do {
            try await delivery.value
            XCTFail("Expected the delivery error")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet)
        }
        XCTAssertEqual(webhookManager.starts.count, 1)
        XCTAssertEqual(webhookManager.sendCount, 0)
    }

    @MainActor
    func testReconciliationForwardsIdentifierAndRunningDelivery() async {
        webhookManager.reconciliationResult = .running(Task { throw URLError(.cancelled) })
        let api = HomeAssistantAPI(server: .fake())
        let identifier = UUID()

        let state = await api.reconcilePersistentEvent(eventIdentifier: identifier)

        guard case let .running(delivery) = state else {
            return XCTFail("Expected the existing delivery task")
        }
        do {
            try await delivery.value
            XCTFail("Expected the adopted task's error")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .cancelled)
        }
        XCTAssertEqual(webhookManager.reconciliations, [identifier.uuidString])
        XCTAssertTrue(webhookManager.starts.isEmpty)
        XCTAssertEqual(webhookManager.sendCount, 0)
    }

    @MainActor
    func testReconciliationForwardsCompletedSuccessAndFailure() async {
        let api = HomeAssistantAPI(server: .fake())
        let identifier = UUID()
        webhookManager.reconciliationResult = .completed(.success(()))

        guard case .completed(.success) = await api.reconcilePersistentEvent(eventIdentifier: identifier) else {
            return XCTFail("Expected the completed success")
        }

        webhookManager.reconciliationResult = .completed(.failure(URLError(.timedOut)))
        let state = await api.reconcilePersistentEvent(eventIdentifier: identifier)
        guard case let .completed(.failure(error)) = state else {
            return XCTFail("Expected the completed failure")
        }
        XCTAssertEqual((error as? URLError)?.code, .timedOut)
        XCTAssertEqual(webhookManager.reconciliations, [identifier.uuidString, identifier.uuidString])
        XCTAssertTrue(webhookManager.starts.isEmpty)
        XCTAssertEqual(webhookManager.sendCount, 0)
    }

    @MainActor
    func testReconciliationForwardsAbsentWithoutStartingUpload() async {
        let api = HomeAssistantAPI(server: .fake())
        let identifier = UUID()
        webhookManager.reconciliationResult = .absent

        guard case .absent = await api.reconcilePersistentEvent(eventIdentifier: identifier) else {
            return XCTFail("Expected no persisted upload")
        }
        XCTAssertEqual(webhookManager.reconciliations, [identifier.uuidString])
        XCTAssertTrue(webhookManager.starts.isEmpty)
        XCTAssertEqual(webhookManager.sendCount, 0)
    }
}
