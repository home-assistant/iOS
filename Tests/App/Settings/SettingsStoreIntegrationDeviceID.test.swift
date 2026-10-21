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
        let previousRecords = Current.settingsStore.prefs.object(forKey: SettingsStore.registrationRecordsKey)
        defer {
            Current.device.identifierForVendor = previousIdentifier
            Current.settingsStore.prefs.set(previousStored, forKey: SettingsStore.integrationDeviceIDKey)
            Current.settingsStore.prefs.set(previousOwner, forKey: SettingsStore.integrationDeviceIDOwnerKey)
            Current.settingsStore.prefs.set(previousRecords, forKey: SettingsStore.registrationRecordsKey)
        }
        Current.settingsStore.prefs.removeObject(forKey: SettingsStore.integrationDeviceIDKey)
        Current.settingsStore.prefs.removeObject(forKey: SettingsStore.integrationDeviceIDOwnerKey)
        Current.settingsStore.prefs.removeObject(forKey: SettingsStore.registrationRecordsKey)
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

    @Test func newIdentifiersHaveNotBeenUsedAndTakeTheSameForm() {
        withVendorIdentifier({ "first-vendor-id" }) {
            let identifier = Current.settingsStore.integrationDeviceID
            let fresh = Current.settingsStore.newIntegrationDeviceID()

            #expect(fresh != identifier)
            #expect(fresh != Current.settingsStore.newIntegrationDeviceID())
            #expect(UUID(uuidString: String(fresh.suffix(36))) != nil)
            #expect(fresh.dropLast(36) == identifier.dropLast("first-vendor-id".count))
        }
    }

    @Test func registrationRecordsAreKeptPerServer() {
        withVendorIdentifier({ "first-vendor-id" }) {
            let settings = Current.settingsStore
            let home = Server.fake(identifier: "home")
            let cabin = Server.fake(identifier: "cabin")
            let identity = RegistrationIdentity(deviceID: "home-device-id", ownerVendorID: "other-vendor-id")
            settings.setRegistrationRecord(RegistrationRecord(current: identity), for: "home")

            #expect(settings.registrationRecord(for: "home") == RegistrationRecord(current: identity))
            #expect(settings.registrationIdentity(for: home) == identity)
            #expect(settings.registrationRecord(for: "cabin") == RegistrationRecord())
            #expect(settings.registrationIdentity(for: cabin) == settings.integrationDeviceIdentity)

            settings.setRegistrationRecord(RegistrationRecord(), for: "home")

            #expect(settings.registrationIdentity(for: home) == settings.integrationDeviceIdentity)
        }
    }

    @Test func anIdentityBeingRegisteredIsTheOneRegisteredWith() {
        withVendorIdentifier({ "first-vendor-id" }) {
            let pending = RegistrationIdentity(deviceID: "new-device-id", ownerVendorID: "first-vendor-id")
            Current.settingsStore.updateRegistrationRecord(for: "home") { record in
                record.current = RegistrationIdentity(deviceID: "old-device-id", ownerVendorID: "other-vendor-id")
                record.pending = pending
            }

            #expect(Current.settingsStore.registrationIdentity(for: Server.fake(identifier: "home")) == pending)
        }
    }

    @Test func anIdentityAnotherDeviceIsRegisteringIsNotRegisteredWith() {
        withVendorIdentifier({ "restored-vendor-id" }) {
            let current = RegistrationIdentity(deviceID: "old-device-id", ownerVendorID: "first-vendor-id")
            Current.settingsStore.updateRegistrationRecord(for: "home") { record in
                record.current = current
                record.pending = RegistrationIdentity(deviceID: "new-device-id", ownerVendorID: "first-vendor-id")
            }

            #expect(Current.settingsStore.registrationIdentity(for: Server.fake(identifier: "home")) == current)
        }
    }

    @Test func theIdentifierKeptWithTheServerStandsInForAMissingRecord() {
        withVendorIdentifier({ "first-vendor-id" }) {
            let server = Server.fake(identifier: "home") {
                $0.setSetting(value: "home-device-id", for: .registeredDeviceID)
            }

            #expect(Current.settingsStore.currentRegistrationIdentity(for: server) == RegistrationIdentity(
                deviceID: "home-device-id",
                ownerVendorID: "first-vendor-id"
            ))
        }
    }

    @Test func unreadableRecordsAreTreatedAsNone() {
        withVendorIdentifier({ "first-vendor-id" }) {
            Current.settingsStore.prefs.set(Data("not json".utf8), forKey: SettingsStore.registrationRecordsKey)

            #expect(Current.settingsStore.registrationRecord(for: "home") == RegistrationRecord())
        }
    }
}
