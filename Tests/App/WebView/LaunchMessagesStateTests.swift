@testable import HomeAssistant
@testable import Shared
import XCTest

@MainActor
final class LaunchMessagesStateTests: XCTestCase {
    func testDismissAllClearsThePresentedMessage() {
        let sut = LaunchMessagesState()
        sut.presented = .whatsNew(Self.release())

        sut.dismissAll()

        XCTAssertNil(sut.presented)
    }

    /// The launch-message sheet calls `showNext()` from `onDismiss`, so dropping only the presented message
    /// would immediately cover whatever an incoming deep link just navigated to.
    func testDismissAllStopsTheQueueFromRePresenting() {
        let sut = LaunchMessagesState()
        sut.presented = .whatsNew(Self.release(id: "first"))
        sut.pending = [.whatsNew(Self.release(id: "second"))]

        sut.dismissAll()
        sut.showNext()

        XCTAssertNil(sut.presented)
        XCTAssertTrue(sut.pending.isEmpty)
    }

    /// Settling registrations a backup brought from another device comes before any other launch message.
    func testRegistrationsOfAnotherDeviceComeFirst() {
        withRegistrationIdentifier(from: "other-device") { servers in
            let server = servers.addFake()

            guard case let .restoredRegistrations(restored)? = LaunchMessagesState.messagesToShow().first else {
                XCTFail("Expected the registrations of another device to come first")
                return
            }
            XCTAssertEqual(restored, [server])
        }
    }

    func testNoPromptForRegistrationsThisDeviceMade() {
        withRegistrationIdentifier(from: "this-device") { servers in
            servers.addFake()

            XCTAssertFalse(LaunchMessagesState.messagesToShow().map(\.id).contains("restoredRegistrations"))
        }
    }

    /// Runs `body` on "this-device", whose stored registration identifier came from `owner`.
    private func withRegistrationIdentifier(
        from owner: String,
        _ body: (FakeServerManager) throws -> Void
    ) rethrows {
        let prefs = Current.settingsStore.prefs
        let previousServers = Current.servers
        let previousVendorID = Current.device.identifierForVendor
        let previousIsCatalyst = Current.isCatalyst
        let keys = [
            SettingsStore.integrationDeviceIDKey,
            SettingsStore.integrationDeviceIDOwnerKey,
            SettingsStore.registrationOwnersKey,
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

        let servers = FakeServerManager(initial: 0)
        Current.servers = servers
        Current.device.identifierForVendor = { "this-device" }
        Current.isCatalyst = false
        keys.forEach(prefs.removeObject(forKey:))
        prefs.set(owner, forKey: SettingsStore.integrationDeviceIDKey)
        try body(servers)
    }

    private static func release(id: String = "test-release") -> WhatsNewRelease {
        WhatsNewRelease(
            id: WhatsNewReleaseId(id),
            version: WhatsNewAppVersion(major: 2026, minor: 1, patch: 0),
            targetPlatforms: [.iPhone],
            items: [
                WhatsNewItem(
                    id: "item",
                    title: "A change",
                    body: "A user-facing change.",
                    icon: .sfSymbol(.checkmark)
                ),
            ]
        )
    }
}
