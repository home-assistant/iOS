import Foundation
import OHHTTPStubs
import OHHTTPStubsSwift
@testable import Shared
import XCTest

final class HomeAssistantAPIRegisterTests: XCTestCase {
    private let keys = [
        SettingsStore.integrationDeviceIDKey,
        SettingsStore.integrationDeviceIDOwnerKey,
        SettingsStore.registrationRecordsKey,
    ]
    private var previousValues = [Any?]()
    private var previousVendorID: (() -> String?)!

    override func setUp() {
        super.setUp()
        let prefs = Current.settingsStore.prefs
        previousValues = keys.map { prefs.object(forKey: $0) }
        keys.forEach(prefs.removeObject(forKey:))
        previousVendorID = Current.device.identifierForVendor
        Current.device.identifierForVendor = { "this-device" }
    }

    override func tearDown() {
        HTTPStubs.removeAllStubs()
        Current.device.identifierForVendor = previousVendorID
        let prefs = Current.settingsStore.prefs
        for (key, value) in zip(keys, previousValues) {
            prefs.set(value, forKey: key)
        }
        super.tearDown()
    }

    private func stubRegistration(statusCode: Int32 = 201) -> () -> String? {
        let body = stubRegistrationBody(statusCode: statusCode)
        return { body()?["device_id"] as? String }
    }

    private func stubRegistrationBody(statusCode: Int32 = 201) -> () -> [String: Any]? {
        var registration: [String: Any]?
        stub(condition: isMethodPOST() && isPath("/api/mobile_app/registrations")) { request in
            let body = request.ohhttpStubs_httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) }
            registration = body as? [String: Any]
            return HTTPStubsResponse(
                jsonObject: ["webhook_id": "new-webhook-id", "secret": "new-secret"],
                statusCode: statusCode,
                headers: ["Content-Type": "application/json"]
            )
        }
        return { registration }
    }

    func testRegistrationBelongsToTheOwnerOfTheIdentifierItWasMadeWith() async throws {
        Current.settingsStore.prefs.set("other-device", forKey: SettingsStore.integrationDeviceIDKey)
        let registeredDeviceID = stubRegistration()
        let server = Server.fake()

        try await HomeAssistantAPI(server: server).register().asyncValue()

        let identity = Current.settingsStore.integrationDeviceIdentity
        XCTAssertEqual(identity.ownerVendorID, "other-device")
        XCTAssertEqual(registeredDeviceID(), identity.deviceID)
        XCTAssertEqual(server.info.connection.webhookID, "new-webhook-id")
        XCTAssertEqual(server.info.connection.webhookSecret, "new-secret")
        XCTAssertEqual(Current.settingsStore.registrationRecord(for: server.identifier).current, identity)
    }

    func testRegisteringAgainKeepsTheIdentityTheRegistrationHas() async throws {
        let registeredDeviceID = stubRegistration()
        let server = Server.fake()
        let identity = RegistrationIdentity(deviceID: "cabin-device-id", ownerVendorID: "this-device")
        Current.settingsStore.setRegistrationRecord(RegistrationRecord(current: identity), for: server.identifier)

        try await HomeAssistantAPI(server: server).register().asyncValue()

        XCTAssertEqual(registeredDeviceID(), "cabin-device-id")
        XCTAssertEqual(Current.settingsStore.registrationRecord(for: server.identifier).current, identity)
    }

    func testAnIdentityBeingRegisteredAsANewDeviceReplacesTheOneTheRegistrationHad() async throws {
        let registeredDeviceID = stubRegistration()
        let server = Server.fake()
        let pending = RegistrationIdentity(deviceID: "new-device-id", ownerVendorID: "this-device")
        Current.settingsStore.setRegistrationRecord(RegistrationRecord(
            current: RegistrationIdentity(deviceID: "old-device-id", ownerVendorID: "other-device"),
            pending: pending
        ), for: server.identifier)

        try await HomeAssistantAPI(server: server).register().asyncValue()

        XCTAssertEqual(registeredDeviceID(), "new-device-id")
        let record = Current.settingsStore.registrationRecord(for: server.identifier)
        XCTAssertEqual(record.current, pending)
        XCTAssertNil(record.pending)
        XCTAssertEqual(server.info.setting(for: .registeredDeviceID), "new-device-id")
    }

    func testRegisteringAgainLeavesAnAttemptAnotherDeviceStarted() async throws {
        let registeredDeviceID = stubRegistration()
        let server = Server.fake()
        let pending = RegistrationIdentity(deviceID: "their-new-device-id", ownerVendorID: "other-device")
        Current.settingsStore.setRegistrationRecord(RegistrationRecord(
            current: RegistrationIdentity(deviceID: "old-device-id", ownerVendorID: "other-device"),
            pending: pending
        ), for: server.identifier)

        try await HomeAssistantAPI(server: server).register().asyncValue()

        XCTAssertEqual(registeredDeviceID(), "old-device-id")
        XCTAssertEqual(Current.settingsStore.registrationRecord(for: server.identifier).pending, pending)
    }

    func testTheIdentifierKeptWithTheServerOutlivesTheAppsRecords() async throws {
        let registeredDeviceID = stubRegistration()
        let server = Server.fake { $0.setSetting(value: "cabin-device-id", for: .registeredDeviceID) }

        try await HomeAssistantAPI(server: server).register().asyncValue()

        XCTAssertEqual(registeredDeviceID(), "cabin-device-id")
        XCTAssertEqual(
            Current.settingsStore.registrationRecord(for: server.identifier).current,
            RegistrationIdentity(
                deviceID: "cabin-device-id",
                ownerVendorID: Current.settingsStore.integrationDeviceIDOwnerVendorID
            )
        )
    }

    func testANameToRegisterWithIsKeptOnlyOnceTheServerHasTheRegistration() async throws {
        let failedRegistration = stubRegistrationBody(statusCode: 500)
        let server = Server.fake { $0.setSetting(value: "Phone", for: .overrideDeviceName) }
        let api = HomeAssistantAPI(server: server)

        do {
            try await api.register(deviceName: "Phone 2").asyncValue()
            XCTFail("the server refused the registration")
        } catch {}

        XCTAssertEqual(failedRegistration()?["device_name"] as? String, "Phone 2")
        XCTAssertEqual(server.info.setting(for: .overrideDeviceName), "Phone")

        HTTPStubs.removeAllStubs()
        _ = stubRegistration()
        try await api.register(deviceName: "Phone 2").asyncValue()

        XCTAssertEqual(server.info.setting(for: .overrideDeviceName), "Phone 2")
        XCTAssertEqual(server.info.setting(for: .registeredDeviceName), "Phone 2")
    }

    func testARegistrationAnotherDeviceOwnsIsNotUpdated() async {
        let previousIsCatalyst = Current.isCatalyst
        Current.isCatalyst = false
        defer { Current.isCatalyst = previousIsCatalyst }
        let server = Server.fake()
        Current.settingsStore.setRegistrationRecord(RegistrationRecord(
            current: RegistrationIdentity(deviceID: "old-device-id", ownerVendorID: "other-device")
        ), for: server.identifier)

        do {
            _ = try await HomeAssistantAPI(server: server).updateRegistration().asyncValue()
            XCTFail("the registration is another device's")
        } catch {
            XCTAssertEqual(error as? RegistrationOwnershipError, .registeredByAnotherDevice)
        }
    }

    func testARegistrationThisDeviceOwnsIsUpdated() async throws {
        let previousWebhooks = Current.webhooks
        let webhooks = FakeWebhookManager()
        Current.webhooks = webhooks
        defer { Current.webhooks = previousWebhooks }
        var sentTypes = [String]()
        webhooks.sendEphemeralHandler = { _, request in
            sentTypes.append(request.type)
            return ["webhook_id": "webhook-id"]
        }
        let server = Server.fake { $0.setSetting(value: "Phone", for: .overrideDeviceName) }
        Current.settingsStore.setRegistrationRecord(RegistrationRecord(
            current: RegistrationIdentity(deviceID: "device-id", ownerVendorID: "this-device")
        ), for: server.identifier)

        _ = try await HomeAssistantAPI(server: server).updateRegistration().asyncValue()

        XCTAssertEqual(sentTypes, ["update_registration"])
        XCTAssertEqual(server.info.setting(for: .registeredDeviceName), "Phone")
    }

    func testTagEventsOnOlderServersNameTheDeviceTheServerKnows() {
        let server = Server.fake { $0.version = Version(minor: 113) }
        let api = HomeAssistantAPI(server: server)
        XCTAssertEqual(api.tagEvent(tagPath: "tag").eventData["device_id"], Current.settingsStore.integrationDeviceID)

        Current.settingsStore.setRegistrationRecord(RegistrationRecord(
            current: RegistrationIdentity(deviceID: "cabin-device-id", ownerVendorID: "this-device"),
            pending: RegistrationIdentity(deviceID: "unconfirmed-device-id", ownerVendorID: "this-device")
        ), for: server.identifier)

        XCTAssertEqual(api.tagEvent(tagPath: "tag").eventData["device_id"], "cabin-device-id")
    }
}
