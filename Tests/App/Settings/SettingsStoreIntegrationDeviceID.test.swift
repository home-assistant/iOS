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
        defer {
            Current.device.identifierForVendor = previousIdentifier
            Current.settingsStore.prefs.set(previousStored, forKey: SettingsStore.integrationDeviceIDKey)
        }
        Current.settingsStore.prefs.removeObject(forKey: SettingsStore.integrationDeviceIDKey)
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
}
