import Foundation
import HAKit
import HAKit_Mocks
import PromiseKit
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

    /// Stands in for the server: answers the registration and the reconnect that follows it.
    private final class RegisteringAPI: HomeAssistantAPI {
        var registerResult: Promise<Void> = .value(())
        var connectResult: Promise<Void> = .value(())
        private(set) var connectReasons = [ConnectReason]()
        private(set) var registeredNames = [String?]()

        override func register(deviceName: String? = nil) -> Promise<Void> {
            registeredNames.append(deviceName)
            return registerResult
        }

        override func Connect(reason: ConnectReason) -> Promise<Void> {
            connectReasons.append(reason)
            return connectResult
        }
    }

    /// Runs `body` with `api` answering for its server.
    private func withAPI(_ api: HomeAssistantAPI, _ body: () async throws -> Void) async rethrows {
        let previousAPIs = Current.cachedApis
        defer { Current.cachedApis = previousAPIs }
        Current.cachedApis = [api.server.identifier: api]
        try await body()
    }

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
            SettingsStore.registrationRecordsKey,
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
        if let owner {
            let settings = Current.settingsStore
            let identity = RegistrationIdentity(deviceID: settings.integrationDeviceID, ownerVendorID: owner)
            settings.setRegistrationRecord(RegistrationRecord(current: identity), for: server.identifier)
        }
        return server
    }

    /// Stands in for the server's WebSocket on `api`, answering the devices it is asked for with `devices`.
    @discardableResult
    private func answerDevices(
        on api: HomeAssistantAPI,
        with devices: [[String: Any]] = []
    ) -> Task<Void, Never> {
        let connection = HAMockConnection()
        api.connection = connection
        return Task {
            guard await waitForRequest(on: connection) else { return }
            connection.pendingRequests[0].completion(.success(.init(value: devices)))
        }
    }

    /// The request is sent from a task of its own, so give it a moment to arrive rather than assuming it is there.
    private func waitForRequest(on connection: HAMockConnection) async -> Bool {
        let deadline = Date().addingTimeInterval(5)
        while connection.pendingRequests.isEmpty, Date() < deadline {
            try? await Task.sleep(nanoseconds: 2_000_000)
        }
        #expect(!connection.pendingRequests.isEmpty)
        return !connection.pendingRequests.isEmpty
    }

    private static func device(named name: String, registeredAs deviceID: String? = nil) -> [String: Any] {
        [
            "id": UUID().uuidString,
            "name": name,
            "identifiers": deviceID.map { [["mobile_app", $0]] } ?? [["hue", UUID().uuidString]],
        ]
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

    @Test func registeringAnewGivesEachServerAFreshIdentityThisDeviceOwns() async {
        await withDevice { servers in
            let restored = [addServer(to: servers, ownedBy: nil), addServer(to: servers, ownedBy: Self.otherDevice)]
            let left = addServer(to: servers, ownedBy: nil)
            let previousIdentity = Current.settingsStore.integrationDeviceIdentity
            var registeredWith = [Server: RegistrationIdentity]()

            let failures = await RegistrationOwnership(register: { server in
                registeredWith[server] = Current.settingsStore.registrationIdentity(for: server)
            }).registerAsNewDevice(restored)

            #expect(failures.isEmpty)
            #expect(Set(registeredWith.keys) == Set(restored))
            #expect(Set(registeredWith.values.map(\.deviceID)).count == restored.count)
            #expect(registeredWith.values.allSatisfy {
                $0.ownerVendorID == Self.thisDevice && $0.deviceID != previousIdentity.deviceID
            })
            // Not registered anew, so it keeps the identity it was made with, which is the other device's.
            #expect(Current.settingsStore.registrationIdentity(for: left) == previousIdentity)
            // What this device registers with from now on, such as a server it is added to later, is its own.
            #expect(Current.settingsStore.integrationDeviceID != previousIdentity.deviceID)
            #expect(Current.settingsStore.integrationDeviceIDOwnerVendorID == Self.thisDevice)
        }
    }

    /// Registering under the identifier the current registration was made with would replace it on the server,
    /// taking it away from any other device using it. The other servers keep the identity they have.
    @Test func registeringAnewOnTheDeviceThatMadeTheRegistrationChangesOnlyThatServersIdentity() async {
        await withDevice(identifierOwner: Self.thisDevice) { servers in
            let server = addServer(to: servers, ownedBy: Self.thisDevice)
            let other = addServer(to: servers, ownedBy: nil)
            let identity = Current.settingsStore.integrationDeviceIdentity

            let failures = await RegistrationOwnership(register: { _ in }).registerAsNewDevice([server])

            #expect(failures.isEmpty)
            #expect(Current.settingsStore.registrationIdentity(for: server).deviceID != identity.deviceID)
            #expect(Current.settingsStore.registrationIdentity(for: other) == identity)
            #expect(Current.settingsStore.integrationDeviceIdentity == identity)
        }
    }

    /// The server may have made the registration before its response was lost, so trying again registers the same
    /// identity, which replaces that registration rather than leaving it behind.
    @Test func registeringAnewAgainReusesTheIdentityOfTheAttemptBefore() async {
        await withDevice { servers in
            let server = addServer(to: servers, ownedBy: Self.otherDevice)
            var registeredWith = [RegistrationIdentity]()
            let ownership = RegistrationOwnership(register: { server in
                registeredWith.append(Current.settingsStore.registrationIdentity(for: server))
                throw RegisterFailure()
            })

            _ = await ownership.registerAsNewDevice([server])
            _ = await ownership.registerAsNewDevice([server])

            #expect(registeredWith.count == 2)
            #expect(registeredWith.first == registeredWith.last)
        }
    }

    /// An attempt the device the backup came from started is that device's to finish.
    @Test func registeringAnewDoesNotReuseAnAttemptAnotherDeviceStarted() async {
        await withDevice { servers in
            let server = addServer(to: servers, ownedBy: Self.otherDevice)
            Current.settingsStore.updateRegistrationRecord(for: server.identifier) { record in
                record.pending = RegistrationIdentity(deviceID: "abandoned", ownerVendorID: Self.otherDevice)
            }
            var registeredWith: RegistrationIdentity?

            _ = await RegistrationOwnership(register: { server in
                registeredWith = Current.settingsStore.registrationIdentity(for: server)
            }).registerAsNewDevice([server])

            #expect(registeredWith?.deviceID != "abandoned")
            #expect(registeredWith?.ownerVendorID == Self.thisDevice)
        }
    }

    @Test func keepingARegistrationAfterFailingToRegisterAnewKeepsItsIdentity() async {
        await withDevice { servers in
            let server = addServer(to: servers, ownedBy: Self.otherDevice)
            let deviceID = Current.settingsStore.registrationIdentity(for: server).deviceID
            _ = await RegistrationOwnership(register: { _ in throw RegisterFailure() }).registerAsNewDevice([server])

            RegistrationOwnership().keepRegistrations(of: [server])

            #expect(Current.settingsStore.registrationRecord(for: server.identifier) == RegistrationRecord(
                current: RegistrationIdentity(deviceID: deviceID, ownerVendorID: Self.thisDevice)
            ))
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

    /// A reconnect that fails leaves the new registration in place, to catch up on the next connect.
    @Test func registeringWithAServerCatchesTheNewRegistrationUp() async throws {
        try await withDevice { servers in
            let server = addServer(to: servers, ownedBy: Self.otherDevice)
            let api = RegisteringAPI(server: server)
            api.connectResult = Promise(error: RegisterFailure())
            answerDevices(on: api)
            SensorRegistrationVersionStore.recordRegistration(for: server.identifier)

            try await withAPI(api) {
                try await RegistrationOwnership.registerWithServer(server)
            }

            #expect(api.connectReasons == [.warm])
            #expect(api.registeredNames == [server.info.mobileAppDeviceName])
            // The new registration has none of the old one's sensors, so the next connect registers them.
            #expect(SensorRegistrationVersionStore.needsRegistration(for: server.identifier))
        }
    }

    @Test func aRegistrationTheServerRefusesIsReported() async {
        await withDevice { servers in
            let server = addServer(to: servers, ownedBy: Self.otherDevice)
            let api = RegisteringAPI(server: server)
            api.registerResult = Promise(error: RegisterFailure())
            answerDevices(on: api, with: [Self.device(named: server.info.mobileAppDeviceName, registeredAs: "other")])

            await withAPI(api) {
                await #expect(throws: RegisterFailure.self) {
                    try await RegistrationOwnership.registerWithServer(server)
                }
            }

            #expect(api.connectReasons.isEmpty)
            #expect(api.registeredNames == ["\(server.info.mobileAppDeviceName) 2"])
        }
    }

    /// Notifications reach a device through an action named after it, so the new registration takes a name none of
    /// the server's other devices has, such as the one it leaves there.
    @Test func registeringWithAServerTakesANameNoOtherDeviceThereHas() async throws {
        try await withDevice { servers in
            let server = addServer(to: servers, ownedBy: Self.otherDevice) { info in
                info.setSetting(value: "Phone", for: .overrideDeviceName)
            }
            let api = RegisteringAPI(server: server)
            answerDevices(on: api, with: [
                Self.device(named: "Phone", registeredAs: "other"),
                Self.device(named: "phone 2", registeredAs: "another"),
            ])

            try await withAPI(api) {
                try await RegistrationOwnership.registerWithServer(server)
            }

            #expect(api.registeredNames == ["Phone 3"])
        }
    }

    @Test func aServerWhoseDevicesCantBeListedIsNotRegisteredWith() async {
        await withDevice { servers in
            let server = addServer(to: servers, ownedBy: Self.otherDevice)
            let api = RegisteringAPI(server: server)
            let connection = HAMockConnection()
            api.connection = connection
            let failure = Task {
                guard await waitForRequest(on: connection) else { return }
                connection.pendingRequests[0].completion(.failure(.internal(debugDescription: "unreachable")))
            }

            await withAPI(api) {
                await #expect(throws: HAError.self) {
                    try await RegistrationOwnership.registerWithServer(server)
                }
            }

            await failure.value
            #expect(api.connectReasons.isEmpty)
        }
    }

    @Test func onlyAnotherRegistrationTakesAName() throws {
        let devices = try [
            Self.device(named: "Phone"),
            Self.device(named: "Tablet", registeredAs: "other"),
            Self.device(named: "Phone 2", registeredAs: "this"),
            Self.device(named: "Laptop_2", registeredAs: "another"),
            Self.device(named: "Laptop", registeredAs: "yet-another"),
        ].map { try DeviceRegistryEntry(data: HAData(value: $0)) }

        // Only another `mobile_app` registration takes a name, and the one being replaced is this device's own.
        #expect(RegistrationOwnership.unusedDeviceName("Phone", among: devices, replacing: "this") == "Phone")
        #expect(RegistrationOwnership.unusedDeviceName("Phone 2", among: devices, replacing: "this") == "Phone 2")
        #expect(RegistrationOwnership.unusedDeviceName("tablet", among: devices, replacing: "this") == "tablet 2")
        // Home Assistant names both "Laptop 2" and "Laptop_2" notify.mobile_app_laptop_2.
        #expect(RegistrationOwnership.unusedDeviceName("Laptop", among: devices, replacing: "this") == "Laptop 3")
    }

    @Test func namesCompareTheWayHomeAssistantNamesNotificationActions() {
        #expect(RegistrationOwnership.notificationName("Bruno's iPhone") == "bruno_s_iphone")
        #expect(RegistrationOwnership.notificationName("  Phone -- 2 ") == "phone_2")
        #expect(RegistrationOwnership.notificationName("Café Ünïcode") == "cafe_unicode")
    }

    /// Reinstalling the app clears its own records but keeps the servers, along with the identifier each one's
    /// registration was made with: the registration is still this device's, under the identifier it has.
    @Test func aRegistrationKeepsTheIdentifierKeptWithTheServerAfterAReinstall() async {
        await withDevice(identifierOwner: Self.thisDevice) { servers in
            let server = addServer(to: servers, ownedBy: nil) { info in
                info.setSetting(value: "cabin-device-id", for: .registeredDeviceID)
            }

            #expect(RegistrationOwnership().serversRegisteredByAnotherDevice().isEmpty)
            #expect(Current.settingsStore.registrationIdentity(for: server).deviceID == "cabin-device-id")
        }
    }

    /// Keeping a registration made before identities were kept with the server keeps its identifier with the server
    /// too, so reinstalling the app, which clears the records and the identifier, doesn't lose it.
    @Test func keepingARegistrationKeepsItsIdentifierWithTheServer() async {
        await withDevice { servers in
            let server = addServer(to: servers, ownedBy: nil)
            let deviceID = Current.settingsStore.integrationDeviceID

            RegistrationOwnership().keepRegistrations(of: [server])
            let prefs = Current.settingsStore.prefs
            prefs.removeObject(forKey: SettingsStore.registrationRecordsKey)
            prefs.removeObject(forKey: SettingsStore.integrationDeviceIDKey)
            prefs.removeObject(forKey: SettingsStore.integrationDeviceIDOwnerKey)

            #expect(Current.settingsStore.integrationDeviceID != deviceID)
            #expect(Current.settingsStore.registrationIdentity(for: server).deviceID == deviceID)
            #expect(RegistrationOwnership().serversRegisteredByAnotherDevice().isEmpty)
        }
    }

    @Test func errorsExplainWhatToDo() {
        #expect(
            RegistrationOwnershipError.noDeviceIdentifier.errorDescription
                == L10n.RestoredRegistrations.Errors.noDeviceIdentifier
        )
        #expect(
            RegistrationOwnershipError.registeredByAnotherDevice.errorDescription
                == L10n.RestoredRegistrations.Errors.registeredByAnotherDevice
        )
    }
}
