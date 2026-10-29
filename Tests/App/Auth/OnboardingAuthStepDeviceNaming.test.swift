import Combine
import HAKit
import HAKit_Mocks
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import SwiftUI
import XCTest

final class OnboardingAuthStepDeviceNamingTests: XCTestCase {
    enum Operation {
        case `default`
        case cancel
    }

    private var step: OnboardingAuthStepDeviceNaming!
    private var api: HomeAssistantAPI!
    private var connection: HAMockConnection!
    private var presenter: OnboardingAuthPresenter!
    private var deviceName: String!
    private var cancellables = Set<AnyCancellable>()

    override func setUp() {
        super.setUp()

        connection = HAMockConnection()
        api = HomeAssistantAPI(server: .fake())
        api.connection = connection

        presenter = OnboardingAuthPresenter()
        cancellables.removeAll()

        connection.automaticallyTransitionToConnecting = false

        let name = "Zac Was Here"
        deviceName = name
        Current.device.deviceName = { name }

        step = OnboardingAuthStepDeviceNaming(api: api, presenter: presenter)
        OnboardingAuthStepDeviceNaming.firstUserDeviceNameInput = false
    }

    override func tearDown() {
        super.tearDown()
        step = nil
        api = nil
        connection = nil
        presenter = nil
        deviceName = nil
    }

    func testSupportedPoints() {
        XCTAssertTrue(OnboardingAuthStepDeviceNaming.supportedPoints.contains(.beforeRegister))
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

        for pendingRequest in connection.pendingRequests {
            pendingRequest.completion(.failure(testError))
        }

        XCTAssertThrowsError(try hang(result)) { error in
            XCTAssertEqual(error as? HAError, testError)
        }
    }

    func testRequestWrongDataType() {
        let result = step.perform(point: .beforeRegister)

        for pendingRequest in connection.pendingRequests {
            pendingRequest.completion(.success(.primitive(true)))
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
        let expectation = setupPresenter(actions: (.cancel, nil))

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
        let expectation = setupPresenter(actions: (.cancel, nil))

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

    func testCancelButtonCancelsOnce() {
        var cancelCount = 0
        let request = OnboardingDeviceNameRequest(onSave: { _, _ in }, onCancel: { cancelCount += 1 })

        request.cancel()
        // The screen disappearing afterwards must not cancel a second time.
        request.cancel()

        XCTAssertEqual(cancelCount, 1)
    }

    func testCancelAfterFinishDoesNothing() {
        var cancelCount = 0
        let request = OnboardingDeviceNameRequest(onSave: { _, _ in }, onCancel: { cancelCount += 1 })

        request.finish()
        request.cancel()

        XCTAssertEqual(cancelCount, 0)
    }

    func testSaveShowsUnreachableErrorWhenDeviceListFails() throws {
        let requestExpectation = expectation(description: "device name request")
        var nameRequest: OnboardingDeviceNameRequest?
        presenter.$path
            .compactMap { path -> OnboardingDeviceNameRequest? in
                guard case let .deviceName(request) = path.last else { return nil }
                return request
            }
            .sink { request in
                nameRequest = request
                requestExpectation.fulfill()
            }
            .store(in: &cancellables)

        _ = step.perform(point: .beforeRegister)
        try respond(result: .success([
            .init(name: deviceName, identifier: "any_other"),
        ]))
        wait(for: [requestExpectation], timeout: 10.0)

        let request = try XCTUnwrap(nameRequest)
        let errorExpectation = expectErrorMessage(on: request)
        request.save("Another Name")

        let command = try XCTUnwrap(connection.pendingRequests.last)
        command.completion(.failure(.internal(debugDescription: "unit-test")))
        wait(for: [errorExpectation], timeout: 10.0)

        XCTAssertEqual(request.errorMessage, L10n.Onboarding.DeviceNameCheck.Error.unreachable)
        XCTAssertFalse(request.isSaving)
    }

    func testSaveShowsUnreachableErrorWhenDeviceListNeverAnswers() throws {
        step.timeout = 0.5

        let requestExpectation = expectation(description: "device name request")
        var nameRequest: OnboardingDeviceNameRequest?
        presenter.$path
            .compactMap { path -> OnboardingDeviceNameRequest? in
                guard case let .deviceName(request) = path.last else { return nil }
                return request
            }
            .sink { request in
                nameRequest = request
                requestExpectation.fulfill()
            }
            .store(in: &cancellables)

        _ = step.perform(point: .beforeRegister)
        try respond(result: .success([
            .init(name: deviceName, identifier: "any_other"),
        ]))
        wait(for: [requestExpectation], timeout: 10.0)

        let request = try XCTUnwrap(nameRequest)
        let errorExpectation = expectErrorMessage(on: request)
        // the device list request is left unanswered
        request.save("Another Name")
        wait(for: [errorExpectation], timeout: 10.0)

        XCTAssertEqual(request.errorMessage, L10n.Onboarding.DeviceNameCheck.Error.unreachable)
        XCTAssertFalse(request.isSaving)
    }

    func testSigningInAgainKeepsTheDeviceTheServerHas() throws {
        let home = Server.fake(identifier: "home") {
            $0.instanceID = "instance-1"
            $0.setSetting(value: "Zac's Phone 2", for: .overrideDeviceName)
        }
        let identity = RegistrationIdentity(deviceID: "home-device-id", ownerVendorID: "this-device")

        try withServers([home]) {
            Current.settingsStore.setRegistrationRecord(RegistrationRecord(current: identity), for: "home")
            discover(instance: "instance-1")

            let result = step.perform(point: .beforeRegister)
            try respond(result: .success([.init(name: "Zac's Phone 2", identifier: "home-device-id")]))
            XCTAssertNoThrow(try hang(result))

            XCTAssertEqual(Current.settingsStore.registrationIdentity(for: api.server), identity)
            XCTAssertEqual(api.server.info.setting(for: .overrideDeviceName), "Zac's Phone 2")
        }
    }

    func testSigningInAtAnAddressSavedServersShareTakesNoneOfTheirDevices() throws {
        let address = URL(string: "http://homeassistant.local:8123")
        let home = Server.fake(identifier: "home") { $0.connection.set(address: address, for: .internal) }
        let cabin = Server.fake(identifier: "cabin") { $0.connection.set(address: address, for: .internal) }

        try withServers([home, cabin]) {
            Current.settingsStore.setRegistrationRecord(RegistrationRecord(
                current: RegistrationIdentity(deviceID: "home-device-id", ownerVendorID: "this-device")
            ), for: "home")
            Current.settingsStore.setRegistrationRecord(RegistrationRecord(
                current: RegistrationIdentity(deviceID: "cabin-device-id", ownerVendorID: "this-device")
            ), for: "cabin")
            signIn(at: address)

            let result = step.perform(point: .beforeRegister)
            try respond(result: .success([.init(name: "Other Phone", identifier: "cabin-device-id")]))
            XCTAssertNoThrow(try hang(result))

            XCTAssertEqual(Current.settingsStore.registrationRecord(for: api.server.identifier), RegistrationRecord())
        }
    }

    func testSigningInAgainKeepsThisServersIdentityOverOneAnotherServerHas() throws {
        let home = Server.fake(identifier: "instance-1")
        let cabin = Server.fake(identifier: "cabin")
        let homeIdentity = RegistrationIdentity(deviceID: "home-device-id", ownerVendorID: "this-device")

        try withServers([home, cabin]) {
            Current.settingsStore.setRegistrationRecord(RegistrationRecord(current: homeIdentity), for: "instance-1")
            Current.settingsStore.setRegistrationRecord(RegistrationRecord(
                current: RegistrationIdentity(deviceID: "old-device-id", ownerVendorID: "this-device")
            ), for: "cabin")
            discover(instance: "instance-1")

            let result = step.perform(point: .beforeRegister)
            try respond(result: .success([.init(name: "Other Phone", identifier: "old-device-id")]))
            XCTAssertNoThrow(try hang(result))

            XCTAssertEqual(Current.settingsStore.registrationIdentity(for: api.server), homeIdentity)
        }
    }

    func testSigningInAgainBeforeOwnershipWasRecordedKeepsTheDeviceTheServerHas() throws {
        let home = Server.fake(identifier: "home") {
            $0.instanceID = "instance-1"
            $0.setSetting(value: "home-device-id", for: .registeredDeviceID)
        }

        try withServers([home]) {
            let prefs = Current.settingsStore.prefs
            prefs.removeObject(forKey: RegistrationOwnership.earlierRegistrationsAdoptedKey)
            prefs.set("other-device", forKey: SettingsStore.integrationDeviceIDKey)
            discover(instance: "instance-1")

            let result = step.perform(point: .beforeRegister)
            try respond(result: .success([.init(name: "Zac's Phone", identifier: "home-device-id")]))
            XCTAssertNoThrow(try hang(result))

            XCTAssertEqual(
                Current.settingsStore.registrationIdentity(for: api.server),
                RegistrationIdentity(deviceID: "home-device-id", ownerVendorID: "this-device")
            )
        }
    }

    func testSigningInAgainToAServerAnotherDeviceIsRegisteredWithRegistersAnew() throws {
        let home = Server.fake(identifier: "instance-1")

        try withServers([home]) {
            Current.settingsStore.setRegistrationRecord(RegistrationRecord(
                current: RegistrationIdentity(deviceID: "old-device-id", ownerVendorID: "other-device")
            ), for: "instance-1")
            discover(instance: "instance-1")

            let result = step.perform(point: .beforeRegister)
            try respond(result: .success([.init(name: "Other Phone", identifier: "old-device-id")]))
            XCTAssertNoThrow(try hang(result))

            let identity = Current.settingsStore.registrationIdentity(for: api.server)
            XCTAssertNotEqual(identity.deviceID, "old-device-id")
            XCTAssertEqual(identity.ownerVendorID, "this-device")
        }
    }

    func testSigningInAgainToADiscoveredServerAnotherDeviceIsRegisteredWithLeavesItsIdentity() throws {
        let home = Server.fake(identifier: "home") { $0.instanceID = "instance-1" }

        try withServers([home]) {
            Current.settingsStore.setRegistrationRecord(RegistrationRecord(
                current: RegistrationIdentity(deviceID: "old-device-id", ownerVendorID: "other-device")
            ), for: "home")
            discover(instance: "instance-1")

            let result = step.perform(point: .beforeRegister)
            try respond(result: .success([.init(name: "Other Phone", identifier: "old-device-id")]))
            XCTAssertNoThrow(try hang(result))

            let identity = Current.settingsStore.registrationIdentity(for: api.server)
            XCTAssertNotEqual(identity.deviceID, "old-device-id")
            XCTAssertEqual(identity.ownerVendorID, "this-device")
        }
    }

    func testSigningInAgainAfterRegisteringAnewFailedKeepsTheIdentityToRegisterUnder() throws {
        let home = Server.fake(identifier: "instance-1")
        let record = RegistrationRecord(
            current: RegistrationIdentity(deviceID: "old-device-id", ownerVendorID: "other-device"),
            pending: RegistrationIdentity(deviceID: "new-device-id", ownerVendorID: "this-device")
        )

        try withServers([home]) {
            Current.settingsStore.setRegistrationRecord(record, for: "instance-1")
            discover(instance: "instance-1")

            let result = step.perform(point: .beforeRegister)
            try respond(result: .success([.init(name: "Other Phone", identifier: "old-device-id")]))
            XCTAssertNoThrow(try hang(result))

            XCTAssertEqual(Current.settingsStore.registrationRecord(for: api.server.identifier), record)
            XCTAssertTrue(RegistrationOwnership().isRegisteredByAnotherDevice(api.server))
        }
    }

    func testSigningInWithAnotherDevicesIdentifierRegistersUnderOneOfItsOwn() throws {
        try withServers([]) {
            Current.settingsStore.prefs.set("other-device", forKey: SettingsStore.integrationDeviceIDKey)
            let otherDevicesID = Current.settingsStore.integrationDeviceID
            signIn(at: URL(string: "http://192.168.1.100:8123"))

            let result = step.perform(point: .beforeRegister)
            try respond(result: .success([.init(name: "Other Phone", identifier: otherDevicesID)]))
            XCTAssertNoThrow(try hang(result))

            let identity = Current.settingsStore.registrationIdentity(for: api.server)
            XCTAssertNotEqual(identity.deviceID, otherDevicesID)
            XCTAssertEqual(identity.ownerVendorID, "this-device")
        }
    }

    func testSigningInAgainKeepsAnIdentityTheServersEntriesShare() throws {
        let home = Server.fake(identifier: "instance-1") { $0.setSetting(value: "Phone", for: .overrideDeviceName) }
        let olderEntry = Server.fake(identifier: "older-entry") {
            $0.instanceID = "instance-1"
            $0.setSetting(value: "Old Phone", for: .overrideDeviceName)
        }
        let shared = RegistrationIdentity(deviceID: "home-device-id", ownerVendorID: "this-device")

        try withServers([home, olderEntry]) {
            Current.settingsStore.setRegistrationRecord(RegistrationRecord(current: shared), for: "instance-1")
            Current.settingsStore.setRegistrationRecord(RegistrationRecord(current: shared), for: "older-entry")
            discover(instance: "instance-1")

            let result = step.perform(point: .beforeRegister)
            try respond(result: .success([.init(name: "Old Phone", identifier: "home-device-id")]))
            XCTAssertNoThrow(try hang(result))

            XCTAssertEqual(Current.settingsStore.registrationIdentity(for: api.server), shared)
            XCTAssertEqual(api.server.info.setting(for: .overrideDeviceName), "Old Phone")
        }
    }

    func testSigningInAgainAfterARecoveryLeavesARegistrationAnotherDeviceOwns() throws {
        let home = Server.fake(identifier: "home") {
            $0.instanceID = "instance-1"
            $0.token = ServerInfo.mirrorPlaceholderToken
        }

        try withServers([home]) {
            Current.settingsStore.setRegistrationRecord(RegistrationRecord(
                current: RegistrationIdentity(deviceID: "home-device-id", ownerVendorID: "other-device")
            ), for: "home")
            discover(instance: "instance-1")

            let result = step.perform(point: .beforeRegister)
            try respond(result: .success([.init(name: "Other Phone", identifier: "home-device-id")]))
            XCTAssertNoThrow(try hang(result))

            let identity = Current.settingsStore.registrationIdentity(for: api.server)
            XCTAssertNotEqual(identity.deviceID, "home-device-id")
            XCTAssertEqual(identity.ownerVendorID, "this-device")
        }
    }

    func testSigningInAgainToAServerAnotherDeviceOwnsTakesNoIdentifierItShares() throws {
        let cabin = Server.fake(identifier: "cabin") { $0.instanceID = "instance-1" }

        try withServers([cabin]) {
            let shared = Current.settingsStore.integrationDeviceID
            Current.settingsStore.setRegistrationRecord(RegistrationRecord(
                current: RegistrationIdentity(deviceID: shared, ownerVendorID: "other-device")
            ), for: "cabin")
            discover(instance: "instance-1")

            let result = step.perform(point: .beforeRegister)
            try respond(result: .success([.init(name: "Other Phone", identifier: shared)]))
            XCTAssertNoThrow(try hang(result))

            let identity = Current.settingsStore.registrationIdentity(for: api.server)
            XCTAssertNotEqual(identity.deviceID, shared)
            XCTAssertEqual(identity.ownerVendorID, "this-device")
        }
    }

    func testSigningInAtAnAddressWithAnIdentifierAnotherServerHasAsAnotherDevicesTakesOneOfItsOwn() throws {
        let cabin = Server.fake(identifier: "cabin")

        try withServers([cabin]) {
            let shared = Current.settingsStore.integrationDeviceID
            Current.settingsStore.setRegistrationRecord(RegistrationRecord(
                current: RegistrationIdentity(deviceID: shared, ownerVendorID: "other-device")
            ), for: "cabin")
            signIn(at: URL(string: "https://cabin.example.com"))

            let result = step.perform(point: .beforeRegister)
            try respond(result: .success([.init(name: "Other Phone", identifier: shared)]))
            XCTAssertNoThrow(try hang(result))

            let identity = Current.settingsStore.registrationIdentity(for: api.server)
            XCTAssertNotEqual(identity.deviceID, shared)
            XCTAssertEqual(identity.ownerVendorID, "this-device")
        }
    }

    func testSigningInAgainAfterAReinstallKeepsTheIdentifierKeptWithTheServer() throws {
        let home = Server.fake(identifier: "instance-1") {
            $0.setSetting(value: "home-device-id", for: .registeredDeviceID)
        }

        try withServers([home]) {
            api = HomeAssistantAPI(server: .fake(identifier: "instance-1"))
            api.connection = connection
            step = OnboardingAuthStepDeviceNaming(api: api, presenter: presenter)

            let result = step.perform(point: .beforeRegister)
            try respond(result: .success([.init(name: deviceName, identifier: "home-device-id")]))
            XCTAssertNoThrow(try hang(result))

            XCTAssertEqual(Current.settingsStore.registrationIdentity(for: api.server).deviceID, "home-device-id")
        }
    }

    func testSigningInToAKnownServerWithoutItsDeviceKeepsItsIdentity() throws {
        let home = Server.fake(identifier: "server-from-an-older-install") { $0.instanceID = "instance-1" }
        let identity = RegistrationIdentity(deviceID: "home-device-id", ownerVendorID: "this-device")

        try withServers([home]) {
            Current.settingsStore.setRegistrationRecord(
                RegistrationRecord(current: identity),
                for: "server-from-an-older-install"
            )
            api = HomeAssistantAPI(server: .fake(identifier: "instance-1"))
            api.connection = connection
            step = OnboardingAuthStepDeviceNaming(api: api, presenter: presenter)

            let result = step.perform(point: .beforeRegister)
            try respond(result: .success([]))
            XCTAssertNoThrow(try hang(result))

            XCTAssertEqual(Current.settingsStore.registrationIdentity(for: api.server), identity)
        }
    }

    private func withServers(_ servers: [Server], _ body: () throws -> Void) rethrows {
        let previousServers = Current.servers
        let previousVendorID = Current.device.identifierForVendor
        let previousIsCatalyst = Current.isCatalyst
        let prefs = Current.settingsStore.prefs
        let keys = [
            SettingsStore.integrationDeviceIDKey,
            SettingsStore.integrationDeviceIDOwnerKey,
            SettingsStore.registrationRecordsKey,
            RegistrationOwnership.earlierRegistrationsAdoptedKey,
        ]
        let previousValues = keys.map { prefs.object(forKey: $0) }
        defer {
            Current.servers = previousServers
            Current.device.identifierForVendor = previousVendorID
            Current.isCatalyst = previousIsCatalyst
            for (key, value) in zip(keys, previousValues) {
                prefs.set(value, forKey: key)
            }
        }

        let manager = FakeServerManager(initial: 0)
        for server in servers {
            manager.add(identifier: server.identifier, serverInfo: server.info)
        }
        Current.servers = manager
        Current.device.identifierForVendor = { "this-device" }
        Current.isCatalyst = false
        keys.forEach(prefs.removeObject(forKey:))
        prefs.set(true, forKey: RegistrationOwnership.earlierRegistrationsAdoptedKey)
        try body()
    }

    private func discover(instance: String) {
        api = HomeAssistantAPI(server: .fake(identifier: .init(rawValue: instance)))
        api.connection = connection
        step = OnboardingAuthStepDeviceNaming(api: api, presenter: presenter)
    }

    private func signIn(at address: URL?) {
        let typedIn = Identifier<Server>(rawValue: DiscoveredHomeAssistant.autogeneratedUUIDPrefix + "typed-in")
        api = HomeAssistantAPI(server: .fake(identifier: typedIn) {
            $0.connection.set(address: address, for: .external)
        })
        api.connection = connection
        step = OnboardingAuthStepDeviceNaming(api: api, presenter: presenter)
    }

    private func expectErrorMessage(on request: OnboardingDeviceNameRequest) -> XCTestExpectation {
        let expectation = expectation(description: "error message")
        request.$errorMessage
            .compactMap { $0 }
            .first()
            .sink { _ in expectation.fulfill() }
            .store(in: &cancellables)
        return expectation
    }

    private func setupPresenter(
        delay: DispatchTimeInterval = .seconds(0),
        actions: (Operation, String?)...
    ) -> XCTestExpectation {
        var pendingActions = actions.makeIterator()

        let expectation = expectation(description: "device name action")
        expectation.expectedFulfillmentCount = actions.count
        presenter.$path
            .compactMap { path -> OnboardingDeviceNameRequest? in
                guard case let .deviceName(request) = path.last else { return nil }
                return request
            }
            .sink { request in
                guard let nextAction = pendingActions.next() else {
                    XCTFail("exceeded setup actions count")
                    return
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    switch nextAction.0 {
                    case .default:
                        request.save(nextAction.1 ?? "")
                    case .cancel:
                        request.cancel()
                    }
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
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
