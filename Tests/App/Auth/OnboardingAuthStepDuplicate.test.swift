import HAKit
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import XCTest

class OnboardingAuthStepDuplicateTests: XCTestCase {
    private var step: OnboardingAuthStepDuplicate!
    private var api: HomeAssistantAPI!
    private var connection: HAMockConnection!
    private var sender: FakeUIViewController!
    private var deviceName: String!

    override func setUp() {
        super.setUp()

        connection = HAMockConnection()
        api = HomeAssistantAPI(server: .fake())
        api.connection = connection

        sender = FakeUIViewController()

        connection.automaticallyTransitionToConnecting = false

        let name = "Zac Was Here"
        deviceName = name
        Current.device.deviceName = { name }

        step = OnboardingAuthStepDuplicate(api: api, sender: sender)
    }

    func testSupportedPoints() {
        XCTAssertTrue(OnboardingAuthStepDuplicate.supportedPoints.contains(.beforeRegister))
    }

    func testNoWebSocketResponseWithoutError() {
        step.timeout = 0
        XCTAssertThrowsError(try hang(step.perform(point: .beforeRegister))) { error in
            XCTAssertEqual((error as? OnboardingAuthError)?.kind, .invalidURL)
        }
    }

    func testNoWebSocketResponseWithError() {
        step.timeout = 0
        connection
            .setState(.disconnected(reason: .waitingToReconnect(
                lastError: TestError.any,
                atLatest: Date(),
                retryCount: 0
            )))
        XCTAssertThrowsError(try hang(step.perform(point: .beforeRegister))) { error in
            XCTAssertEqual(error as? TestError, .any)
        }
    }

    func testRequestError() {
        let result = step.perform(point: .beforeRegister)
        let testError = HAError.internal(debugDescription: "unit-test")

        connection.pendingRequests.forEach {
            $0.completion(.failure(testError))
        }

        XCTAssertThrowsError(try hang(result)) { error in
            XCTAssertEqual(error as? HAError, testError)
        }
    }

    func testRequestWrongDataType() {
        let result = step.perform(point: .beforeRegister)

        connection.pendingRequests.forEach {
            $0.completion(.success(.primitive(true)))
        }

        XCTAssertThrowsError(try hang(result)) { error in
            XCTAssertEqual(error as? HomeAssistantAPI.APIError, .invalidResponse)
        }
    }

    func testNoExistingIntegrations() throws {
        let result = step.perform(point: .beforeRegister)
        try respond(result: .success([]))
        XCTAssertNoThrow(try hang(result))
    }

    func testExistingNameSameIdentifier() throws {
        let result = step.perform(point: .beforeRegister)
        try respond(result: .success([
            .init(name: deviceName, identifier: Current.settingsStore.integrationDeviceID),
        ]))
        XCTAssertNoThrow(try hang(result))
    }

    func testDuplicateCancelled() throws {
        let expectation = setupSender(actions: (.cancel, nil))

        let result = step.perform(point: .beforeRegister)
        try respond(result: .success([
            .init(name: deviceName, identifier: "any_other"),
        ]))
        wait(for: [expectation], timeout: 10.0)

        XCTAssertThrowsError(try hang(result)) { error in
            if case PMKError.cancelled = error {
                // pass
            } else {
                XCTFail("invalid error type, got \(error)")
            }
        }
    }

    func testDuplicateLowercasedDeviceNameCancelled() throws {
        let expectation = setupSender(actions: (.cancel, nil))

        let result = step.perform(point: .beforeRegister)
        try respond(result: .success([
            .init(name: deviceName.lowercased(), identifier: "any_other"),
        ]))
        wait(for: [expectation], timeout: 10.0)

        XCTAssertThrowsError(try hang(result)) { error in
            if case PMKError.cancelled = error {
                // pass
            } else {
                XCTFail("invalid error type, got \(error)")
            }
        }
    }

    func testDuplicateChangedToNew() throws {
        let expectation = setupSender(actions: (.default, "New Name"))

        let result = step.perform(point: .beforeRegister)
        try respond(result: .success([
            .init(name: deviceName, identifier: "any_other"),
        ]))
        wait(for: [expectation], timeout: 10.0)

        XCTAssertNoThrow(try hang(result))
        XCTAssertEqual(api.server.info.setting(for: .overrideDeviceName), "New Name")
    }

    func testTimeoutBeforeUserFlowFinished() throws {
        // just enough to enqueue and execute before the alert action below
        step.timeout = 0.01

        let expectation = setupSender(delay: .milliseconds(100), actions: (.default, "New Name"))

        let result = step.perform(point: .beforeRegister)
        try respond(result: .success([
            .init(name: deviceName, identifier: "any_other"),
        ]))
        wait(for: [expectation], timeout: 10.0)

        XCTAssertNoThrow(try hang(result))
    }

    func testDuplicateChangedToExistingThenExistingThenCancelled() throws {
        let expectation = setupSender(actions: (.default, deviceName), (.default, deviceName), (.cancel, nil))

        let result = step.perform(point: .beforeRegister)
        try respond(result: .success([
            .init(name: deviceName, identifier: "any_other"),
        ]))
        wait(for: [expectation], timeout: 10.0)

        XCTAssertThrowsError(try hang(result)) { error in
            if case PMKError.cancelled = error {
                // pass
            } else {
                XCTFail("invalid error type, got \(error)")
            }
        }
    }

    func testDuplicateChangedToEmptyThenNew() throws {
        let expectation = setupSender(actions: (.default, ""), (.default, "New Name 2"))

        let result = step.perform(point: .beforeRegister)
        try respond(result: .success([
            .init(name: deviceName, identifier: "any_other1"),
        ]))
        wait(for: [expectation], timeout: 10.0)

        XCTAssertNoThrow(try hang(result))
        XCTAssertEqual(api.server.info.setting(for: .overrideDeviceName), "New Name 2")
    }

    func testDuplicateChangedToExistingThenExistingThenNew() throws {
        let expectation = setupSender(actions: (.default, "New Name"), (.default, "New Name"), (.default, "New Name 2"))

        let result = step.perform(point: .beforeRegister)
        try respond(result: .success([
            .init(name: deviceName, identifier: "any_other1"),
            .init(name: "New Name", identifier: "any_other2"),
        ]))
        wait(for: [expectation], timeout: 10.0)

        XCTAssertNoThrow(try hang(result))
        XCTAssertEqual(api.server.info.setting(for: .overrideDeviceName), "New Name 2")
    }

    private func setupSender(
        delay: DispatchTimeInterval = .seconds(0),
        actions: (UIAlertAction.Style, String?)...
    ) -> XCTestExpectation {
        var pendingActions = actions.makeIterator()

        let expectation = expectation(description: "alert action")
        expectation.expectedFulfillmentCount = actions.count
        sender.didPresent = { vc in
            guard let vc = vc as? UIAlertController else {
                XCTFail("invalid presented controller")
                return
            }

            guard let nextAction = pendingActions.next() else {
                XCTFail("exceeded setup actions count")
                return
            }

            guard let action = vc.actions.first(where: { $0.style == nextAction.0 }) else {
                XCTFail("no action found")
                return
            }

            vc.textFields?.forEach { $0.text = nextAction.1 }

            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                action.ha_handler(action)
                expectation.fulfill()
            }
        }
        return expectation
    }

    private struct ResponseDevice {
        var name: String
        var identifier: String
    }

    private func respond(result: Swift.Result<[ResponseDevice], HAError>) throws {
        let command = try XCTUnwrap(connection.pendingRequests.first(where: {
            $0.request.type.command == "config/device_registry/list"
        }))

        command.completion(result.map { devices in
            let responseJSON: [[String: Any]] = [
                // a bunch of decode failures, which should not affect anything
                [:],
                ["name": "other_integration_name"],
                ["name": 3],
                ["identifiers": [[String]]()],
                ["identifiers": false],
                ["name": "other_integration_name", "identifiers": [[String]]()],
                ["name": "other_integration_name", "identifiers": [["mobile_bat", "moo"]]],
            ] + devices.map { device in
                [
                    "name": device.name,
                    "identifiers": [
                        ["mobile_app", device.identifier],
                    ],
                    "additional_unused_key1": true,
                    "additional_unused_key2": 3,
                ]
            }

            return HAData(value: responseJSON)
        })
    }
}

private enum TestError: Error {
    case any
}

private class FakeUIViewController: UIViewController {
    var didPresent: ((UIViewController) -> Void)?

    override func present(
        _ viewControllerToPresent: UIViewController,
        animated flag: Bool,
        completion: (() -> Void)? = nil
    ) {
        didPresent?(viewControllerToPresent)
        completion?()
    }
}
