import Foundation
import HAKit
import HAKit_Mocks
import PromiseKit
@testable import Shared
import Testing

// Serialized: the tests swap `Current` and the app group's stored registration identifier.
@Suite(.serialized)
struct RegistrationOwnershipTests {
    private static let thisDevice = "this-device"
    private static let otherDevice = "other-device"

    private struct RegisterFailure: Error {}

    private actor AsyncGate {
        private var isOpen = false
        private var waiters = [CheckedContinuation<Void, Never>]()

        func wait() async {
            guard !isOpen else { return }
            await withCheckedContinuation { waiters.append($0) }
        }

        func open() {
            isOpen = true
            waiters.forEach { $0.resume() }
            waiters.removeAll()
        }
    }

    private final class RegisteringAPI: HomeAssistantAPI {
        var registerResult: Promise<Void> = .value(())
        var connectResult: Promise<Void> = .value(())
        private(set) var connectReasons = [ConnectReason]()
        private(set) var registeredNames = [String?]()
        private(set) var updatedRegistrations = 0

        override func register(deviceName: String? = nil) -> Promise<Void> {
            registeredNames.append(deviceName)
            return registerResult
        }

        override func updateRegistration() -> Promise<MobileAppRegistrationResponse> {
            updatedRegistrations += 1
            return Promise(error: RegisterFailure())
        }

        override func Connect(reason: ConnectReason) -> Promise<Void> {
            connectReasons.append(reason)
            return connectResult
        }
    }

    private final class ConnectingAPI: HomeAssistantAPI {
        private(set) var updatedRegistrations = 0

        override func updateRegistration() -> Promise<MobileAppRegistrationResponse> {
            updatedRegistrations += 1
            return Promise(error: RegisterFailure())
        }
    }

    private func keep(_ servers: [Server]) {
        RegistrationOwnership(catchUp: { _ in }).keepRegistrations(of: servers)
    }

    private func withAPI(_ api: HomeAssistantAPI, _ body: () async throws -> Void) async rethrows {
        let previousAPIs = Current.cachedApis
        defer { Current.cachedApis = previousAPIs }
        Current.cachedApis = [api.server.identifier: api]
        try await body()
    }

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
            RegistrationOwnership.heldBackNotifiedKey,
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

    /// Lets the main queue run what was put on it so far.
    private func drainMainQueue() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }

    private func noteHeldBack(
        by server: Server,
        inForeground: Bool = false,
        notified: @escaping (Server) -> Void
    ) async {
        let previous = Current.isForegroundApp
        defer { Current.isForegroundApp = previous }
        Current.isForegroundApp = { inForeground }
        RegistrationOwnership(notify: notified).noteHeldBack(by: server)
        await drainMainQueue()
    }

    @Test func heldBackReportsAreToldAboutOncePerServer() async {
        await withDevice { servers in
            let first = addServer(to: servers, ownedBy: Self.otherDevice)
            let second = addServer(to: servers, ownedBy: Self.otherDevice)
            var notified = [Server]()

            await noteHeldBack(by: first) { notified.append($0) }
            await noteHeldBack(by: first) { notified.append($0) }
            await noteHeldBack(by: second) { notified.append($0) }

            #expect(notified == [first, second])
        }
    }

    @Test func heldBackReportsAreNotToldAboutWhileTheAppIsOpen() async {
        await withDevice { servers in
            let server = addServer(to: servers, ownedBy: Self.otherDevice)
            var notified = [Server]()

            await noteHeldBack(by: server, inForeground: true) { notified.append($0) }
            #expect(notified.isEmpty)

            // The app asks on screen, so a background launch after it still tells.
            await noteHeldBack(by: server) { notified.append($0) }
            #expect(notified == [server])
        }
    }

    @Test func heldBackReportsAreToldAboutAgainForAnotherDevice() async {
        await withDevice { servers in
            let server = addServer(to: servers, ownedBy: Self.otherDevice)
            var notified = [Server]()
            await noteHeldBack(by: server) { notified.append($0) }

            let settings = Current.settingsStore
            settings.setRegistrationRecord(
                RegistrationRecord(current: RegistrationIdentity(
                    deviceID: settings.integrationDeviceID,
                    ownerVendorID: "yet-another-device"
                )),
                for: server.identifier
            )
            await noteHeldBack(by: server) { notified.append($0) }

            #expect(notified == [server, server])
        }
    }

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

            keep(kept)

            #expect(RegistrationOwnership().serversRegisteredByAnotherDevice().isEmpty)
            #expect(Current.settingsStore.integrationDeviceID == identifier)
            #expect(Current.settingsStore.integrationDeviceIDOwnerVendorID == Self.thisDevice)
        }
    }

    @Test func keepingSomeRegistrationsLeavesTheOthersToTheDeviceTheyCameFrom() async {
        await withDevice { servers in
            let kept = addServer(to: servers, ownedBy: nil)
            let left = addServer(to: servers, ownedBy: nil)

            keep([kept])

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
            #expect(Current.settingsStore.registrationIdentity(for: left) == previousIdentity)
            #expect(Current.settingsStore.integrationDeviceID != previousIdentity.deviceID)
            #expect(Current.settingsStore.integrationDeviceIDOwnerVendorID == Self.thisDevice)
        }
    }

    @Test func registeringAnewOnTheDeviceThatMadeTheRegistrationLeavesItsIdentifierBehind() async {
        await withDevice(identifierOwner: Self.thisDevice) { servers in
            let server = addServer(to: servers, ownedBy: Self.thisDevice)
            let other = addServer(to: servers, ownedBy: nil)
            let identity = Current.settingsStore.integrationDeviceIdentity

            let failures = await RegistrationOwnership(register: { _ in }).registerAsNewDevice([server])

            #expect(failures.isEmpty)
            #expect(Current.settingsStore.registrationIdentity(for: server).deviceID != identity.deviceID)
            #expect(Current.settingsStore.registrationIdentity(for: other) == identity)
            #expect(Current.settingsStore.integrationDeviceID != identity.deviceID)
            #expect(Current.settingsStore.integrationDeviceIDOwnerVendorID == Self.thisDevice)
        }
    }

    @Test func registeringAnewAgainKeepsTheDefaultIdentifier() async {
        await withDevice(identifierOwner: Self.thisDevice) { servers in
            let server = addServer(to: servers, ownedBy: Self.thisDevice)
            Current.settingsStore.setRegistrationRecord(RegistrationRecord(
                current: RegistrationIdentity(deviceID: "its-own-device-id", ownerVendorID: Self.thisDevice)
            ), for: server.identifier)
            let identity = Current.settingsStore.integrationDeviceIdentity

            _ = await RegistrationOwnership(register: { _ in }).registerAsNewDevice([server])

            #expect(Current.settingsStore.integrationDeviceIdentity == identity)
        }
    }

    @Test func keepingARegistrationCatchesItUpWithThisDevice() async {
        await withDevice { servers in
            let server = addServer(to: servers, ownedBy: Self.otherDevice)
            let api = RegisteringAPI(server: server)

            await withAPI(api) {
                RegistrationOwnership().keepRegistrations(of: [server])
            }

            #expect(api.connectReasons == [.warm])
            #expect(api.updatedRegistrations == 0)
        }
    }

    @Test func registeringAnewTwiceAtOnceRegistersOnce() async {
        await withDevice { servers in
            let server = addServer(to: servers, ownedBy: Self.otherDevice)
            let gate = AsyncGate()
            var registrations = 0
            let ownership = RegistrationOwnership(register: { _ in
                registrations += 1
                await gate.wait()
            })

            async let first = ownership.registerAsNewDevice([server])
            async let second = ownership.registerAsNewDevice([server])
            try? await Task.sleep(for: .milliseconds(50))
            await gate.open()
            let failures = await [first, second]

            let noneFailed = failures.allSatisfy(\.isEmpty)
            #expect(registrations == 1)
            #expect(noneFailed)
        }
    }

    @Test func aFailureIsSharedByTheAttemptsThatJoinedIt() async {
        await withDevice { servers in
            let server = addServer(to: servers, ownedBy: Self.otherDevice)
            let gate = AsyncGate()
            let ownership = RegistrationOwnership(register: { _ in
                await gate.wait()
                throw RegisterFailure()
            })

            async let first = ownership.registerAsNewDevice([server])
            async let second = ownership.registerAsNewDevice([server])
            try? await Task.sleep(for: .milliseconds(50))
            await gate.open()
            let failures = await [first, second]

            let bothFailed = failures.allSatisfy { $0[server] is RegisterFailure }
            #expect(bothFailed)
        }
    }

    @Test func anAttemptThatFinishedDoesNotStandInForTheNext() async {
        await withDevice { servers in
            let server = addServer(to: servers, ownedBy: Self.otherDevice)
            var registrations = 0
            let ownership = RegistrationOwnership(register: { _ in registrations += 1 })

            _ = await ownership.registerAsNewDevice([server])
            _ = await ownership.registerAsNewDevice([server])

            #expect(registrations == 2)
        }
    }

    @Test func aConnectLeavesAnotherDevicesRegistrationAlone() async {
        await withDevice { servers in
            let theirs = addServer(to: servers, ownedBy: Self.otherDevice)
            let api = ConnectingAPI(server: theirs)
            api.connection = HAMockConnection()

            await withAPI(api) {
                api.Connect(reason: .warm).cauterize()
            }

            #expect(api.updatedRegistrations == 0)
        }
    }

    @Test func reportsAreHeldBackWhileTheRegistrationIsAnotherDevices() async {
        await withDevice { servers in
            let theirs = addServer(to: servers, ownedBy: Self.otherDevice)
            let mine = addServer(to: servers, ownedBy: Self.thisDevice)
            let ownership = RegistrationOwnership()

            for type in ["update_location", "update_sensor_states", "register_sensor"] {
                #expect(ownership.holdsBack(WebhookRequest(type: type, data: [:]), to: theirs))
                #expect(!ownership.holdsBack(WebhookRequest(type: type, data: [:]), to: mine))
            }
            for type in ["call_service", "fire_event", "get_config", "render_template", "update_registration"] {
                #expect(!ownership.holdsBack(WebhookRequest(type: type, data: [:]), to: theirs))
            }
        }
    }

    /// The server may have made the registration before its response was lost.
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

            keep([server])

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

    @Test func registeringAnewRegistersWithTheServerByDefault() async {
        await withDevice { servers in
            let server = addServer(to: servers, ownedBy: Self.otherDevice)
            let api = RegisteringAPI(server: server)
            answerDevices(on: api)

            await withAPI(api) {
                let failures = await RegistrationOwnership(catchUp: { _ in }).registerAsNewDevice([server])
                #expect(failures.isEmpty)
            }

            #expect(api.registeredNames == [server.info.mobileAppDeviceName])
            #expect(api.connectReasons == [.warm])
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
            #expect(SensorRegistrationVersionStore.needsRegistration(for: server.identifier))
        }
    }

    @Test func registeringWithAServerStopsWaitingForAReconnectThatDoesNotFinish() async throws {
        let previousTimeout = RegistrationOwnership.reconnectTimeout
        RegistrationOwnership.reconnectTimeout = 0.1
        defer { RegistrationOwnership.reconnectTimeout = previousTimeout }

        try await withDevice { servers in
            let server = addServer(to: servers, ownedBy: Self.otherDevice)
            let api = RegisteringAPI(server: server)
            let (reconnect, seal) = Promise<Void>.pending()
            api.connectResult = reconnect
            answerDevices(on: api)

            try await withAPI(api) {
                try await RegistrationOwnership.registerWithServer(server)
            }
            seal.fulfill(())

            #expect(api.registeredNames == [server.info.mobileAppDeviceName])
            #expect(api.connectReasons == [.warm])
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

    /// Notification actions are named after devices, so the name must be unique on the server.
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

        #expect(RegistrationOwnership.unusedDeviceName("Phone", among: devices, replacing: "this") == "Phone")
        #expect(RegistrationOwnership.unusedDeviceName("Phone 2", among: devices, replacing: "this") == "Phone 2")
        #expect(RegistrationOwnership.unusedDeviceName("tablet", among: devices, replacing: "this") == "tablet 2")
        #expect(RegistrationOwnership.unusedDeviceName("Laptop", among: devices, replacing: "this") == "Laptop 3")
    }

    @Test func aNumberedNameCountsOnFromTheNameItCameFrom() throws {
        let devices = try [
            Self.device(named: "Phone", registeredAs: "first"),
            Self.device(named: "Phone 2", registeredAs: "second"),
            Self.device(named: "iPhone 15", registeredAs: "third"),
            Self.device(named: "Pixel 8", registeredAs: "fourth"),
            Self.device(named: "Pixel", registeredAs: "fifth"),
        ].map { try DeviceRegistryEntry(data: HAData(value: $0)) }

        #expect(RegistrationOwnership.unusedDeviceName("Phone 2", among: devices, replacing: "this") == "Phone 3")
        #expect(RegistrationOwnership.unusedDeviceName("iPhone 15", among: devices, replacing: "this") == "iPhone 15 2")
        #expect(RegistrationOwnership.unusedDeviceName("Pixel 8", among: devices, replacing: "this") == "Pixel 2")
        #expect(RegistrationOwnership.unusedDeviceName("Pixel 8", among: devices, replacing: "fourth") == "Pixel 8")
    }

    @Test func namesCompareTheWayHomeAssistantNamesNotificationActions() {
        #expect(RegistrationOwnership.notificationName("Bruno's iPhone") == "bruno_s_iphone")
        #expect(RegistrationOwnership.notificationName("  Phone -- 2 ") == "phone_2")
        #expect(RegistrationOwnership.notificationName("Café Ünïcode") == "cafe_unicode")
        #expect(RegistrationOwnership.notificationName("Phone 1,000, 2") == "phone_1000_2")
        #expect(RegistrationOwnership.notificationName("Søren") == "soren")
        #expect(RegistrationOwnership.notificationName("Straße") == "strasse")
        #expect(RegistrationOwnership.notificationName("Bjørn") == RegistrationOwnership.notificationName("Bjorn"))
    }

    @Test func aCommaBetweenDigitsDoesNotTellNamesApart() throws {
        let devices = try [
            Self.device(named: "Phone 1000", registeredAs: "other"),
            Self.device(named: "Phone 1,2", registeredAs: "another"),
            Self.device(named: "Phone 12 2", registeredAs: "yet-another"),
        ].map { try DeviceRegistryEntry(data: HAData(value: $0)) }

        let name: (String) -> String = { RegistrationOwnership.unusedDeviceName($0, among: devices, replacing: "this") }
        #expect(name("Phone 1,000") == "Phone 1,000 2")
        #expect(name("Phone 1,2") == "Phone 1,2 3")
    }

    @Test func aRegistrationKeepsTheIdentifierKeptWithTheServerAfterAReinstall() async {
        await withDevice(identifierOwner: Self.thisDevice) { servers in
            let server = addServer(to: servers, ownedBy: nil) { info in
                info.setSetting(value: "cabin-device-id", for: .registeredDeviceID)
            }

            #expect(RegistrationOwnership().serversRegisteredByAnotherDevice().isEmpty)
            #expect(Current.settingsStore.registrationIdentity(for: server).deviceID == "cabin-device-id")
        }
    }

    @Test func keepingARegistrationKeepsItsIdentifierWithTheServer() async {
        await withDevice { servers in
            let server = addServer(to: servers, ownedBy: nil)
            let deviceID = Current.settingsStore.integrationDeviceID

            keep([server])
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
