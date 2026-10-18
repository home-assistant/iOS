import Foundation
@testable import Shared
import Testing

/// A device restored from another one's backup carries that device's registrations; these cover telling them apart
/// and settling them.
// Serialized: the tests swap `Current` and the app group's stored registration identifier.
@Suite(.serialized)
struct RegistrationOwnershipTests {
    private static let thisDevice = "this-device"
    private static let otherDevice = "other-device"

    private struct RegisterFailure: Error {}

    /// Runs `body` on a device with `vendorID`, whose stored registration identifier came from `identifierOwner`.
    private func withDevice<T>(
        vendorID: String? = RegistrationOwnershipTests.thisDevice,
        identifierOwner: String = RegistrationOwnershipTests.otherDevice,
        _ body: (FakeServerManager) async throws -> T
    ) async rethrows -> T {
        let prefs = Current.settingsStore.prefs
        let keys = [
            SettingsStore.integrationDeviceIDKey,
            SettingsStore.integrationDeviceIDOwnerKey,
            SettingsStore.registrationOwnersKey,
        ]
        let previousValues = keys.map { prefs.object(forKey: $0) }
        let previousServers = Current.servers
        let previousVendorID = Current.device.identifierForVendor
        let previousIsCatalyst = Current.isCatalyst
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
        Current.device.identifierForVendor = { vendorID }
        Current.isCatalyst = false
        keys.forEach(prefs.removeObject(forKey:))
        prefs.set(identifierOwner, forKey: SettingsStore.integrationDeviceIDKey)
        return try await body(servers)
    }

    /// Adds a server whose registration was recorded as `owner`'s, or predates owners being recorded when `nil`.
    @discardableResult
    private func addServer(
        to servers: FakeServerManager,
        ownedBy owner: String?,
        update: (inout ServerInfo) -> Void = { _ in }
    ) -> Server {
        var info = ServerInfo.fake()
        update(&info)
        let server = servers.add(identifier: .init(rawValue: UUID().uuidString), serverInfo: info)
        Current.settingsStore.setRegistrationOwnerVendorID(owner, for: server.identifier)
        return server
    }

    @Test func registrationsOfTheDeviceTheBackupCameFromAreFound() async {
        await withDevice { servers in
            let unrecorded = addServer(to: servers, ownedBy: nil)
            let others = addServer(to: servers, ownedBy: Self.otherDevice)
            addServer(to: servers, ownedBy: Self.thisDevice)
            addServer(to: servers, ownedBy: Self.otherDevice) { info in
                // Waiting to be signed in to again after a recovery, so it can't be registered with yet.
                info.token = ServerInfo.mirrorPlaceholderToken
            }

            #expect(RegistrationOwnership().serversRegisteredByAnotherDevice() == [unrecorded, others])
        }
    }

    @Test func registrationsMadeUnderThisDevicesIdentifierAreItsOwn() async {
        await withDevice(identifierOwner: Self.thisDevice) { servers in
            addServer(to: servers, ownedBy: nil)

            #expect(RegistrationOwnership().serversRegisteredByAnotherDevice().isEmpty)
        }
    }

    @Test func theMacNeverReportsRegistrationsOfAnotherDevice() async {
        await withDevice { servers in
            addServer(to: servers, ownedBy: Self.otherDevice)
            Current.isCatalyst = true

            #expect(RegistrationOwnership().serversRegisteredByAnotherDevice().isEmpty)
        }
    }

    @Test func nothingIsReportedWithoutAVendorIdentifier() async {
        await withDevice(vendorID: nil) { servers in
            addServer(to: servers, ownedBy: Self.otherDevice)

            #expect(RegistrationOwnership().serversRegisteredByAnotherDevice().isEmpty)
        }
    }

    @Test func keepingRegistrationsMakesThemAndTheIdentifierThisDevices() async {
        await withDevice { servers in
            let kept = [addServer(to: servers, ownedBy: nil), addServer(to: servers, ownedBy: Self.otherDevice)]
            let identifier = Current.settingsStore.integrationDeviceID

            RegistrationOwnership().keepRegistrations(of: kept)

            #expect(RegistrationOwnership().serversRegisteredByAnotherDevice().isEmpty)
            #expect(Current.settingsStore.integrationDeviceID == identifier)
            #expect(Current.settingsStore.integrationDeviceIDOwnerVendorID == Self.thisDevice)
        }
    }

    @Test func keepingSomeRegistrationsLeavesTheOthersToTheDeviceTheyCameFrom() async {
        await withDevice { servers in
            let kept = addServer(to: servers, ownedBy: nil)
            let left = addServer(to: servers, ownedBy: nil)

            RegistrationOwnership().keepRegistrations(of: [kept])

            #expect(RegistrationOwnership().serversRegisteredByAnotherDevice() == [left])
        }
    }

    @Test func registeringAnewUsesAFreshIdentifierThisDeviceOwns() async throws {
        try await withDevice { servers in
            let restored = [addServer(to: servers, ownedBy: nil), addServer(to: servers, ownedBy: Self.otherDevice)]
            let left = addServer(to: servers, ownedBy: nil)
            let previousIdentifier = Current.settingsStore.integrationDeviceID
            var registeredWith = [Server: String]()

            let failures = await RegistrationOwnership(register: { server in
                registeredWith[server] = Current.settingsStore.integrationDeviceID
            }).registerAsNewDevice(restored)

            #expect(failures.isEmpty)
            #expect(Set(registeredWith.keys) == Set(restored))
            #expect(Set(registeredWith.values) == [Current.settingsStore.integrationDeviceID])
            #expect(Current.settingsStore.integrationDeviceID != previousIdentifier)
            let stored = try #require(Current.settingsStore.prefs.string(forKey: SettingsStore.integrationDeviceIDKey))
            #expect(UUID(uuidString: stored) != nil)
            #expect(Current.settingsStore.integrationDeviceIDOwnerVendorID == Self.thisDevice)
            // Not registered anew, so its registration is still recorded as the other device's.
            #expect(Current.settingsStore.registrationOwnerVendorID(for: left.identifier) == Self.otherDevice)
        }
    }

    /// Registering under the identifier the current registration was made with would replace it on the server,
    /// taking it away from any other device using it.
    @Test func registeringAnewOnTheDeviceThatMadeTheRegistrationStillChangesTheIdentifier() async {
        await withDevice(identifierOwner: Self.thisDevice) { servers in
            let server = addServer(to: servers, ownedBy: Self.thisDevice)
            let previousIdentifier = Current.settingsStore.integrationDeviceID

            let failures = await RegistrationOwnership(register: { _ in }).registerAsNewDevice([server])

            #expect(failures.isEmpty)
            #expect(Current.settingsStore.integrationDeviceID != previousIdentifier)
            #expect(Current.settingsStore.integrationDeviceIDOwnerVendorID == Self.thisDevice)
        }
    }

    @Test func serversThatFailToRegisterAreReported() async {
        await withDevice { servers in
            let registered = addServer(to: servers, ownedBy: Self.otherDevice)
            let failed = addServer(to: servers, ownedBy: Self.otherDevice)

            let failures = await RegistrationOwnership(register: { server in
                if server == failed {
                    throw RegisterFailure()
                }
            }).registerAsNewDevice([registered, failed])

            #expect(Array(failures.keys) == [failed])
            #expect(failures[failed] is RegisterFailure)
        }
    }

    @Test func registeringAnewWithoutAVendorIdentifierChangesNothing() async {
        await withDevice(vendorID: nil) { servers in
            let server = addServer(to: servers, ownedBy: Self.otherDevice)
            let previousIdentifier = Current.settingsStore.integrationDeviceID
            var registered = false

            let failures = await RegistrationOwnership(register: { _ in
                registered = true
            }).registerAsNewDevice([server])

            #expect(failures[server] as? RegistrationOwnershipError == .noDeviceIdentifier)
            #expect(!registered)
            #expect(Current.settingsStore.integrationDeviceID == previousIdentifier)
        }
    }

    @Test func registeringWithAServerNeedsAURLToReachIt() async {
        await withDevice { servers in
            let server = addServer(to: servers, ownedBy: Self.otherDevice) { info in
                info.connection.set(address: nil, for: .external)
                info.connection.set(address: nil, for: .internal)
            }

            await #expect(throws: ServerConnectionError.self) {
                try await RegistrationOwnership.registerWithServer(server)
            }
        }
    }

    @Test func noDeviceIdentifierExplainsWhatToDo() {
        #expect(
            RegistrationOwnershipError.noDeviceIdentifier.errorDescription
                == L10n.RestoredRegistrations.Errors.noDeviceIdentifier
        )
    }
}
