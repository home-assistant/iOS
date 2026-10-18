@testable import Shared
import Testing

/// The identifier the server knows the installation by is taken from the vendor identifier once and kept.
// Serialized: the tests swap `Current.device.identifierForVendor` and the stored value, which concurrent
// tests would race on.
@Suite(.serialized)
struct SettingsStoreIntegrationDeviceIDTests {
    private func withVendorIdentifier(
        _ identifier: @escaping () -> String?,
        _ body: () throws -> Void
    ) rethrows {
        let previousIdentifier = Current.device.identifierForVendor
        let previousStored = Current.settingsStore.prefs.string(forKey: SettingsStore.integrationDeviceIDKey)
        let previousOwner = Current.settingsStore.prefs.string(forKey: SettingsStore.integrationDeviceIDOwnerKey)
        let previousRegistrationOwners = Current.settingsStore.prefs.object(forKey: SettingsStore.registrationOwnersKey)
        defer {
            Current.device.identifierForVendor = previousIdentifier
            Current.settingsStore.prefs.set(previousStored, forKey: SettingsStore.integrationDeviceIDKey)
            Current.settingsStore.prefs.set(previousOwner, forKey: SettingsStore.integrationDeviceIDOwnerKey)
            Current.settingsStore.prefs.set(previousRegistrationOwners, forKey: SettingsStore.registrationOwnersKey)
        }
        Current.settingsStore.prefs.removeObject(forKey: SettingsStore.integrationDeviceIDKey)
        Current.settingsStore.prefs.removeObject(forKey: SettingsStore.integrationDeviceIDOwnerKey)
        Current.settingsStore.prefs.removeObject(forKey: SettingsStore.registrationOwnersKey)
        Current.device.identifierForVendor = identifier
        try body()
    }

    @Test func theFirstVendorIdentifierIsKeptWhenItLaterChanges() {
        withVendorIdentifier({ "first-vendor-id" }) {
            let first = Current.settingsStore.integrationDeviceID
            #expect(first.hasSuffix("first-vendor-id"))

            Current.device.identifierForVendor = { "second-vendor-id" }

            #expect(Current.settingsStore.integrationDeviceID == first)
        }
    }

    @Test func nothingIsKeptWhileThereIsNoVendorIdentifier() {
        withVendorIdentifier({ nil }) {
            #expect(Current.settingsStore.integrationDeviceID.hasSuffix(Current.settingsStore.deviceID))
            #expect(Current.settingsStore.prefs.string(forKey: SettingsStore.integrationDeviceIDKey) == nil)

            Current.device.identifierForVendor = { "late-vendor-id" }

            #expect(Current.settingsStore.integrationDeviceID.hasSuffix("late-vendor-id"))
        }
    }

    /// A backup carries the stored identifier to another device, where it still names the device it came from.
    @Test func theIdentifierBelongsToTheDeviceItCameFrom() {
        withVendorIdentifier({ "first-vendor-id" }) {
            _ = Current.settingsStore.integrationDeviceID
            Current.device.identifierForVendor = { "restored-vendor-id" }

            #expect(Current.settingsStore.integrationDeviceIDOwnerVendorID == "first-vendor-id")
        }
    }

    @Test func takingOverTheIdentifierKeepsIt() {
        withVendorIdentifier({ "first-vendor-id" }) {
            let identifier = Current.settingsStore.integrationDeviceID

            Current.settingsStore.takeOverIntegrationDeviceID(for: "restored-vendor-id")

            #expect(Current.settingsStore.integrationDeviceID == identifier)
            #expect(Current.settingsStore.integrationDeviceIDOwnerVendorID == "restored-vendor-id")
        }
    }

    @Test func adoptingGivesAnIdentifierNoRegistrationHasUsed() {
        withVendorIdentifier({ "first-vendor-id" }) {
            let identifier = Current.settingsStore.integrationDeviceID

            Current.settingsStore.adoptNewIntegrationDeviceID(ownedBy: "first-vendor-id")
            let adopted = Current.settingsStore.integrationDeviceID
            Current.settingsStore.adoptNewIntegrationDeviceID(ownedBy: "first-vendor-id")

            #expect(adopted != identifier)
            #expect(!adopted.hasSuffix("first-vendor-id"))
            #expect(Current.settingsStore.integrationDeviceID != adopted)
            #expect(Current.settingsStore.integrationDeviceIDOwnerVendorID == "first-vendor-id")
        }
    }

    @Test func registrationOwnersAreRecordedPerServer() {
        withVendorIdentifier({ "first-vendor-id" }) {
            Current.settingsStore.setRegistrationOwnerVendorID("other-vendor-id", for: "home")

            #expect(Current.settingsStore.registrationOwnerVendorID(for: "home") == "other-vendor-id")
            #expect(Current.settingsStore.registrationOwnerVendorID(for: "cabin") == nil)

            Current.settingsStore.setRegistrationOwnerVendorID(nil, for: "home")

            #expect(Current.settingsStore.registrationOwnerVendorID(for: "home") == nil)
        }
    }
}
