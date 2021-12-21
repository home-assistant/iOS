import Foundation
import PromiseKit
@testable import Shared
import XCTest

class WebhookResponseUpdateSensorsTests: XCTestCase {
    private var api: FakeHomeAssistantAPI!

    private var previousWebhookManager: WebhookManager!
    private var webhookManager: FakeWebhookManager!

    override func setUp() {
        super.setUp()

        api = FakeHomeAssistantAPI(server: .fake())
        webhookManager = FakeWebhookManager()
        previousWebhookManager = Current.webhooks
        Current.webhooks = webhookManager
    }

    override func tearDown() {
        super.tearDown()

        Current.webhooks = previousWebhookManager
    }

    func testReplacement() throws {
        let request1 = WebhookRequest(type: "update_sensor_states", data: ["unique_id": "test1"])
        let request2 = WebhookRequest(type: "update_sensor_states", data: ["unique_id": "test1"])
        let request3 = WebhookRequest(type: "update_sensor_states", data: ["unique_id": "test2"])

        XCTAssertTrue(WebhookResponseUpdateSensors.shouldReplace(request: request1, with: request2))
        XCTAssertTrue(WebhookResponseUpdateSensors.shouldReplace(request: request2, with: request3))
        XCTAssertTrue(WebhookResponseUpdateSensors.shouldReplace(request: request3, with: request1))
    }

    func testUpdatedWithoutIssue() throws {
        let handler = WebhookResponseUpdateSensors(api: api)
        let request = WebhookRequest(type: "update_sensor_states", data: [:])
        let result: [String: [String: Any]] = [
            "one": WebhookSensorResponse(success: true).toJSON(),
        ]

        let expectation = self.expectation(description: "result")
        handler.handle(request: .value(request), result: .value(result)).done { handlerResult in
            XCTAssertNil(handlerResult.notification)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10)
    }

    func testUpdatedWithInvalidResponse() throws {
        let handler = WebhookResponseUpdateSensors(api: api)
        let request = WebhookRequest(type: "update_sensor_states", data: [:])
        let result: [String: Any] = [
            "one": ["not an object here"],
        ]

        let expectation = self.expectation(description: "result")
        handler.handle(request: .value(request), result: .value(result)).done { handlerResult in
            XCTAssertNil(handlerResult.notification)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 10)
    }

    func testUpdatedRequiringRegistration() throws {
        // it's probably too much work to mock out the sensors here, so this implicitly
        // depends on one of the registered sensors. to make this more obvious, grab one.
        let sensors = try hang(Promise(Current.sensors.sensors(reason: .registration, server: api.server))).sensors
        let handler = WebhookResponseUpdateSensors(api: api)
        let request = WebhookRequest(type: "update_sensor_states", data: [:])

        let expectedRegisteredKeys = Set(sensors[0 ... 1].map { $0.UniqueID! })
        // false-positive, changing to short hand doesn't compile
        let result = [String: [String: Any]](uniqueKeysWithValues: sensors.enumerated().map { idx, sensor in
            if idx <= 1 {
                return (sensor.UniqueID!, WebhookSensorResponse(
                    success: false,
                    errorMessage: "booboo1",
                    errorCode: "not_registered"
                ).toJSON())
            } else {
                return (sensor.UniqueID!, WebhookSensorResponse(success: true).toJSON())
            }
        })

        var registeredIDs = Set<String>()

        webhookManager.sendRequestHandler = { [api] _, server, request, seal in
            XCTAssertEqual(request.type, "register_sensor")
            XCTAssertEqual(server, api?.server)

            do {
                let dictionary = try request.asDictionary()

                if let uniqueID = dictionary["unique_id"] as? String {
                    registeredIDs.insert(uniqueID)
                } else {
                    XCTFail("unexpected sensor being asked to register")
                }

                seal.fulfill(())
            } catch {
                seal.reject(error)
            }
        }

        let promise = handler.handle(request: .value(request), result: .value(result)).done { handlerResult in
            XCTAssertNil(handlerResult.notification)
        }

        XCTAssertNoThrow(try hang(Promise(promise)))

        // possible problems here -- over-registering, under-registering, not-at-all registering
        // all covered by equality at least
        XCTAssertEqual(registeredIDs, expectedRegisteredKeys)
    }
}

private class FakeHomeAssistantAPI: HomeAssistantAPI {}
