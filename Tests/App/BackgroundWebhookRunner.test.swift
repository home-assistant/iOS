import Foundation
@testable import HomeAssistant
import OHHTTPStubs
import OHHTTPStubsSwift
import PromiseKit
@testable import Shared
import XCTest

final class BackgroundWebhookRunnerTests: XCTestCase {
    @MainActor
    func testNormalSendAndPersistedUploadCompleteWithApplicationRunner() async throws {
        let previousRunner = Current.backgroundTask
        let previousImmediate = Current.isBackgroundRequestsImmediate
        let previousApis = Current.cachedApis
        defer {
            HTTPStubs.removeAllStubs()
            Current.backgroundTask = previousRunner
            Current.isBackgroundRequestsImmediate = previousImmediate
            Current.cachedApis = previousApis
        }

        let workerLease = expectation(description: "normal send acquired a lease on dataQueue")
        let mainLease = expectation(description: "persisted upload acquired a lease on main")
        Current.backgroundTask = ApplicationBackgroundTaskRunner(
            beginTask: { name, _ in
                if name == BackgroundTask.webhookSend.rawValue {
                    if Thread.isMainThread {
                        mainLease.fulfill()
                    } else {
                        workerLease.fulfill()
                    }
                }
                return .invalid
            },
            endTask: { _ in XCTFail("Invalid background task must not be ended") },
            remainingTime: {
                XCTAssertTrue(Thread.isMainThread)
                return 20
            }
        )
        Current.isBackgroundRequestsImmediate = { true }
        let api = FakeHassAPI(server: .fake())
        Current.cachedApis = [api.server.identifier: api]
        let manager = WebhookManager()
        let url = api.server.info.connection.evaluateWebhookURL()
        let received = expectation(description: "both uploads reached the endpoint")
        received.expectedFulfillmentCount = 2
        stub(condition: { $0.url == url }, response: { _ in
            received.fulfill()
            return HTTPStubsResponse(jsonObject: ["result": true], statusCode: 200, headers: nil)
        })

        // No suspension between these calls: send enqueues on the real dataQueue first,
        // then persisted creation synchronously joins that same queue from main.
        let ordinary = manager.send(
            server: api.server,
            request: WebhookRequest(type: "fire_event", data: ["event_type": "ordinary"])
        )
        let persisted = manager.startPersistedBackground(
            server: api.server,
            request: WebhookRequest(type: "fire_event", data: ["event_type": "persisted"]),
            requestIdentifier: UUID().uuidString
        )
        guard case let .success(delivery) = persisted else {
            return XCTFail("Expected persisted upload creation to succeed")
        }
        try await ordinary.asyncValue()
        try await delivery.value
        await fulfillment(of: [workerLease, mainLease, received], timeout: 10)
    }
}
