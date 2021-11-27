import PromiseKit
@testable import Shared
import XCTest

class WebhookResponseLocationTests: XCTestCase {
    private var api: HomeAssistantAPI!

    enum TestError: Error {
        case any
    }

    override func setUp() {
        super.setUp()

        api = HomeAssistantAPI(server: .fake())
    }

    func testReplacement() throws {
        let request1 = WebhookRequest(type: "update_location", data: ["gps": [0, 1]])
        let request2 = WebhookRequest(type: "update_location", data: ["gps": [0, 1]])
        let request3 = WebhookRequest(type: "update_location", data: ["gps": [1, 2]])

        XCTAssertTrue(WebhookResponseLocation.shouldReplace(request: request1, with: request2))
        XCTAssertTrue(WebhookResponseLocation.shouldReplace(request: request2, with: request3))
        XCTAssertTrue(WebhookResponseLocation.shouldReplace(request: request3, with: request1))
    }

    func testNotifications() throws {
        for trigger in LocationUpdateTrigger.allCases {
            for prefState in [true, false] {
                try test(trigger: trigger, preferenceState: prefState)
            }
        }
    }

    func testLackingLocalMetadata() {
        let handler = WebhookResponseLocation(api: api)
        let promise = handler.handle(
            request: .value(WebhookRequest(
                type: "update_location",
                data: [:]
            )), result: .value(
                [:]
            )
        )
        XCTAssertNil(try hang(Promise(promise)).notification)
    }

    func testErrorUpdating() {
        let handler = WebhookResponseLocation(api: api)
        let promise = handler.handle(
            request: .value(WebhookRequest(
                type: "update_location",
                data: [:],
                localMetadata: WebhookResponseLocation.localMetdata(
                    trigger: .AppShortcut,
                    zone: nil
                )
            )), result: .init(error: TestError.any)
        )
        XCTAssertNil(try hang(Promise(promise)).notification)
    }

    private func test(trigger: LocationUpdateTrigger, preferenceState: Bool) throws {
        let notificationExpected: Bool

        if let key = trigger.notificationPreferenceKey {
            notificationExpected = preferenceState
            Current.settingsStore.prefs.set(preferenceState, forKey: key)
        } else {
            notificationExpected = false
        }

        let handler = WebhookResponseLocation(api: api)
        let promise = handler.handle(
            request: .value(WebhookRequest(
                type: "update_location",
                data: [:],
                localMetadata: WebhookResponseLocation.localMetdata(
                    trigger: trigger,
                    zone: nil
                )
            )), result: .value(
                [:]
            )
        )

        XCTAssertEqual(try hang(Promise(promise)).notification != nil, notificationExpected)
    }
}
