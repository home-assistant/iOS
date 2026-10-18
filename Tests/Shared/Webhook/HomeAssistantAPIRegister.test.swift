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
        SettingsStore.registrationOwnersKey,
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

    /// A device restored from another one's backup registers under that device's identifier until it is told
    /// otherwise, so the registration it makes is recorded as that device's.
    func testRegistrationBelongsToTheOwnerOfTheIdentifierItWasMadeWith() async throws {
        Current.settingsStore.prefs.set("other-device", forKey: SettingsStore.integrationDeviceIDKey)
        stub(condition: isMethodPOST() && isPath("/api/mobile_app/registrations")) { _ in
            HTTPStubsResponse(
                jsonObject: ["webhook_id": "new-webhook-id", "secret": "new-secret"],
                statusCode: 201,
                headers: ["Content-Type": "application/json"]
            )
        }
        let server = Server.fake()

        try await HomeAssistantAPI(server: server).register().asyncValue()

        XCTAssertEqual(server.info.connection.webhookID, "new-webhook-id")
        XCTAssertEqual(server.info.connection.webhookSecret, "new-secret")
        XCTAssertEqual(Current.settingsStore.registrationOwnerVendorID(for: server.identifier), "other-device")
    }
}
