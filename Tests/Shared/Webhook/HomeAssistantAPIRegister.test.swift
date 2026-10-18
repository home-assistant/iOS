import Foundation
import OHHTTPStubs
import OHHTTPStubsSwift
@testable import Shared
import XCTest

/// What registering with a server records about the registration it makes.
final class HomeAssistantAPIRegisterTests: XCTestCase {
    private let keys = [
        SettingsStore.integrationDeviceIDKey,
        SettingsStore.integrationDeviceIDOwnerKey,
        SettingsStore.registrationRecordsKey,
    ]
    private var previousValues = [Any?]()

    override func setUp() {
        super.setUp()
        let prefs = Current.settingsStore.prefs
        previousValues = keys.map { prefs.object(forKey: $0) }
        keys.forEach(prefs.removeObject(forKey:))
    }

    override func tearDown() {
        HTTPStubs.removeAllStubs()
        let prefs = Current.settingsStore.prefs
        for (key, value) in zip(keys, previousValues) {
            prefs.set(value, forKey: key)
        }
        super.tearDown()
    }

    /// Answers the registration, keeping the `device_id` it was made with.
    private func stubRegistration() -> () -> String? {
        var deviceID: String?
        stub(condition: isMethodPOST() && isPath("/api/mobile_app/registrations")) { request in
            let body = request.ohhttpStubs_httpBody.flatMap { try? JSONSerialization.jsonObject(with: $0) }
            deviceID = (body as? [String: Any])?["device_id"] as? String
            return HTTPStubsResponse(
                jsonObject: ["webhook_id": "new-webhook-id", "secret": "new-secret"],
                statusCode: 201,
                headers: ["Content-Type": "application/json"]
            )
        }
        return { deviceID }
    }

    /// A device restored from another one's backup registers under that device's identifier until it is told
    /// otherwise, so the registration it makes is recorded as that device's.
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

    /// Registering again, such as when the server lost the registration, keeps the device it had there, whatever
    /// this device registers other servers with.
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
    }

    /// Older servers learn which device scanned a tag from the event itself, so it names the device the server knows
    /// this one as, never one it is still being registered as.
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
