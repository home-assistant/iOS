import Foundation
import HAKit
import HAKit_Mocks
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import SharedTesting
import Testing

/// Stands in for the database updater so a Sync in a test never reaches the network.
private final class IdleAppDatabaseUpdater: AppDatabaseUpdaterProtocol {
    private(set) var updatedServers: [Server] = []

    func stop() {}

    func update(server: Server, forceUpdate: Bool, showProgress: Bool) {
        updatedServers.append(server)
    }
}

/// Covers what the server screen's view model derives for the details row: the URLs, which one is in
/// use, the Sync button's in-flight state, and the invitation link behind the share button.
@Suite(.sharedState)
@MainActor
struct ConnectionSettingsViewModelTests {
    private func makeServer(
        identifier: String = "test-server",
        internalURL: String?,
        externalURL: String?,
        remoteUIURL: String? = nil,
        useCloud: Bool = false
    ) -> Server {
        var info = ServerInfo(
            name: "Test Server",
            connection: .init(
                externalURL: externalURL.flatMap(URL.init(string:)),
                internalURL: internalURL.flatMap(URL.init(string:)),
                cloudhookURL: nil,
                remoteUIURL: remoteUIURL.flatMap(URL.init(string:)),
                webhookID: "webhook-id",
                webhookSecret: nil,
                internalSSIDs: nil,
                internalHardwareAddresses: nil,
                isLocalPushEnabled: false,
                securityExceptions: .init(),
                connectionAccessSecurityLevel: .lessSecure
            ),
            token: .init(accessToken: "token", refreshToken: "refresh", expiration: Date()),
            version: "2024.1"
        )
        info.connection.useCloud = useCloud
        return Server.fake(identifier: .init(rawValue: identifier), initial: info)
    }

    private func withTestWorld<T>(_ body: () async throws -> T) async rethrows -> T {
        let previousServers = Current.servers
        let previousUpdater = Current.appDatabaseUpdater
        defer {
            Current.servers = previousServers
            Current.appDatabaseUpdater = previousUpdater
        }
        Current.servers = FakeServerManager(initial: 0)
        Current.appDatabaseUpdater = IdleAppDatabaseUpdater()
        return try await body()
    }

    /// On the Mac, with only native features on, activating a server opens it in the browser.
    @Test func activatingOnTheMacWithNativeFeaturesOnlyOpensTheBrowser() async {
        let previousCatalyst = Current.isCatalyst
        let previousNativeOnly = Current.settingsStore.macNativeFeaturesOnly
        defer {
            Current.isCatalyst = previousCatalyst
            Current.settingsStore.macNativeFeaturesOnly = previousNativeOnly
        }
        Current.isCatalyst = true
        Current.settingsStore.macNativeFeaturesOnly = true

        await withTestWorld {
            await RecordingURLOpener.with { opener in
                let server = makeServer(internalURL: nil, externalURL: "https://external.example.com")
                let viewModel = ConnectionSettingsViewModel(server: server)
                viewModel.activateServer(on: nil)

                let deadline = Date().addingTimeInterval(10)
                while opener.openedURLs.isEmpty, Date() < deadline {
                    try? await Task.sleep(nanoseconds: 20_000_000)
                }
                #expect(opener.openedURLs.map(\.url.host) == ["external.example.com"])
            }
        }
    }

    @Test func urlsAndActiveTypeFollowTheServer() async {
        await withTestWorld {
            let server = makeServer(internalURL: "http://internal.example.com:8123", externalURL: nil)
            let viewModel = ConnectionSettingsViewModel(server: server)

            #expect(viewModel.internalURL == "http://internal.example.com:8123")
            #expect(viewModel.externalURL == nil)
            #expect(viewModel.externalAddress == nil)
            #expect(!viewModel.isUsingCloud)
            #expect(viewModel.activeURLType == .internal)
            #expect(viewModel.version == "2024.1")
        }
    }

    @Test func cloudReplacesTheExternalURL() async {
        await withTestWorld {
            let server = makeServer(
                internalURL: nil,
                externalURL: "https://external.example.com",
                remoteUIURL: "https://example.ui.nabu.casa",
                useCloud: true
            )
            let viewModel = ConnectionSettingsViewModel(server: server)

            #expect(viewModel.isUsingCloud)
            #expect(viewModel.externalURL == AppConstants.homeAssistantLinkName)
            #expect(viewModel.externalAddress == "https://example.ui.nabu.casa")
            #expect(viewModel.activeURLType == .remoteUI)
        }
    }

    @Test func syncEndsWhenThisServerFinishes() async throws {
        try await withTestWorld {
            let server = makeServer(internalURL: "http://internal.example.com:8123", externalURL: nil)
            let otherServer = makeServer(identifier: "other", internalURL: "http://other.example.com", externalURL: nil)
            let viewModel = ConnectionSettingsViewModel(server: server)
            #expect(!viewModel.isSyncing)

            viewModel.updateAppDatabase()
            #expect(viewModel.isSyncing)

            AppDatabaseUpdaterUserInfo.postDidFinish(serverId: otherServer.identifier.rawValue)
            try await Task.sleep(for: .milliseconds(50))
            #expect(viewModel.isSyncing)

            AppDatabaseUpdaterUserInfo.postDidFinish(serverId: server.identifier.rawValue)
            try await Task.sleep(for: .milliseconds(50))
            #expect(!viewModel.isSyncing)
        }
    }

    @Test func editRoutesEachOptionToItsEditor() async {
        await withTestWorld {
            let server = makeServer(internalURL: "http://internal.example.com:8123", externalURL: nil)
            server.info.setSetting(value: "Cabin", for: .localName)
            server.info.setSetting(value: "My Phone", for: .overrideDeviceName)
            let viewModel = ConnectionSettingsViewModel(server: server)

            viewModel.edit(.locationName)
            #expect(viewModel.nameBeingEdited == .locationName)
            #expect(viewModel.nameDraft == "Cabin")
            viewModel.cancelNameEdit()
            #expect(viewModel.nameBeingEdited == nil)

            viewModel.edit(.deviceName)
            #expect(viewModel.nameBeingEdited == .deviceName)
            #expect(viewModel.nameDraft == "My Phone")
            viewModel.cancelNameEdit()

            viewModel.edit(.internalURL)
            #expect(viewModel.isEditingInternalURL)
            viewModel.edit(.externalURL)
            #expect(viewModel.isEditingExternalURL)
            #expect(viewModel.nameBeingEdited == nil)
        }
    }

    @Test func namePlaceholdersFallBackToWhatTheAppUses() async {
        await withTestWorld {
            let previousDeviceName = Current.device.deviceName
            defer { Current.device.deviceName = previousDeviceName }
            Current.device.deviceName = { "Test iPhone" }

            let viewModel = ConnectionSettingsViewModel(
                server: makeServer(internalURL: "http://internal.example.com:8123", externalURL: nil)
            )
            #expect(viewModel.namePlaceholder(for: .locationName) == "Test Server")
            #expect(viewModel.namePlaceholder(for: .deviceName) == "Test iPhone")
            #expect(viewModel.namePlaceholder(for: .internalURL).isEmpty)
            #expect(viewModel.namePlaceholder(for: .externalURL).isEmpty)
        }
    }

    @Test func savingTheNameDraftWritesTheEditedName() async {
        await withTestWorld {
            let server = makeServer(internalURL: "http://internal.example.com:8123", externalURL: nil)
            let viewModel = ConnectionSettingsViewModel(server: server)

            viewModel.edit(.locationName)
            viewModel.nameDraft = "Cabin"
            viewModel.saveNameDraft()
            #expect(server.info.setting(for: .localName) == "Cabin")
            #expect(viewModel.locationName == "Cabin")
            #expect(viewModel.nameBeingEdited == nil)

            viewModel.edit(.deviceName)
            viewModel.nameDraft = "My Phone"
            viewModel.saveNameDraft()
            #expect(server.info.setting(for: .overrideDeviceName) == "My Phone")
            #expect(viewModel.deviceName == "My Phone")

            viewModel.edit(.locationName)
            viewModel.nameDraft = ""
            viewModel.saveNameDraft()
            #expect(server.info.setting(for: .localName) == nil)
            #expect(viewModel.locationName.isEmpty)

            viewModel.saveNameDraft()
            #expect(viewModel.nameBeingEdited == nil)
        }
    }

    @Test func certificatePickWaitsForAPassword() async {
        await withTestWorld {
            let viewModel = ConnectionSettingsViewModel(
                server: makeServer(internalURL: "http://internal.example.com:8123", externalURL: nil)
            )
            let picked = URL(fileURLWithPath: "/tmp/home.p12")

            viewModel.handleCertificatePick(.success([picked]))
            #expect(viewModel.pendingCertificateURL == picked)
            #expect(viewModel.isCertificatePasswordPromptPresented)

            viewModel.certificatePassword = "secret"
            viewModel.cancelCertificateImport()
            #expect(viewModel.pendingCertificateURL == nil)
            #expect(viewModel.certificatePassword.isEmpty)

            viewModel.handleCertificatePick(.success([]))
            #expect(viewModel.pendingCertificateURL == nil)

            viewModel.handleCertificatePick(.failure(URLError(.cancelled)))
            #expect(viewModel.pendingCertificateURL == nil)
        }
    }

    @Test func confirmingAnUnreadableCertificateReportsTheError() async {
        await withTestWorld {
            let viewModel = ConnectionSettingsViewModel(
                server: makeServer(internalURL: "http://internal.example.com:8123", externalURL: nil)
            )

            await viewModel.confirmCertificateImport()
            #expect(viewModel.certificateError == nil)

            viewModel.handleCertificatePick(.success([URL(fileURLWithPath: "/nonexistent/home.p12")]))
            viewModel.certificatePassword = "secret"
            await viewModel.confirmCertificateImport()
            #expect(viewModel.certificateError != nil)
            #expect(viewModel.clientCertificate == nil)
            #expect(viewModel.pendingCertificateURL == nil)
            #expect(viewModel.certificatePassword.isEmpty)
            #expect(!viewModel.isImportingCertificate)
        }
    }

    /// A certificate stored outside this screen, as Re-authenticate does, shows up while it is open.
    @Test func clientCertificateFollowsTheServer() async {
        await withTestWorld {
            let server = makeServer(internalURL: nil, externalURL: "https://external.example.com")
            let viewModel = ConnectionSettingsViewModel(server: server)
            #expect(viewModel.clientCertificate == nil)

            let certificate = ClientCertificate(keychainIdentifier: "stored", displayName: "Stored")
            server.update { $0.connection.clientCertificate = certificate }

            for _ in 0 ..< 3000 where viewModel.clientCertificate == nil {
                try? await Task.sleep(for: .milliseconds(10))
            }
            #expect(viewModel.clientCertificate == certificate)
        }
    }

    @Test func invitationURLNeedsAnAddressToInviteTo() async {
        await withTestWorld {
            let shareable = ConnectionSettingsViewModel(
                server: makeServer(internalURL: nil, externalURL: "https://external.example.com")
            )
            #expect(shareable.invitationURL() != nil)
            #expect(shareable.canShareServer)

            let unreachable = ConnectionSettingsViewModel(server: makeServer(internalURL: nil, externalURL: nil))
            #expect(unreachable.invitationURL() == nil)
            #expect(!unreachable.canShareServer)
        }
    }

    private func withRegistrationIdentifierRestored(_ body: () async throws -> Void) async rethrows {
        let prefs = Current.settingsStore.prefs
        let previousVendorID = Current.device.identifierForVendor
        let keys = [
            SettingsStore.integrationDeviceIDKey,
            SettingsStore.integrationDeviceIDOwnerKey,
            SettingsStore.registrationRecordsKey,
            RegistrationOwnership.earlierRegistrationsAdoptedKey,
        ]
        let previousValues = keys.map { prefs.object(forKey: $0) }
        defer {
            Current.device.identifierForVendor = previousVendorID
            for (key, value) in zip(keys, previousValues) {
                prefs.set(value, forKey: key)
            }
        }
        Current.device.identifierForVendor = { "this-device" }
        prefs.set(true, forKey: RegistrationOwnership.earlierRegistrationsAdoptedKey)
        try await body()
    }

    @Test func registeringAsANewDeviceRegistersWithThisServer() async {
        await withTestWorld {
            await withRegistrationIdentifierRestored {
                let server = makeServer(internalURL: "http://internal.example.com:8123", externalURL: nil)
                var registered = [Server]()
                var titlesWhileRegistering = [String]()
                var viewModel: ConnectionSettingsViewModel!
                var signedIn = [Server]()
                viewModel = ConnectionSettingsViewModel(
                    server: server,
                    ownership: RegistrationOwnership(register: {
                        titlesWhileRegistering.append(viewModel.registerAsNewDeviceTitle)
                        registered.append($0)
                    }),
                    signIn: { server, _ in signedIn.append(server) }
                )
                #expect(viewModel.registerAsNewDeviceTitle == L10n.Settings.ConnectionSection.RegisterAsNewDevice.title)

                await viewModel.registerAsNewDevice()

                #expect(signedIn == [server])
                #expect(registered == [server])
                #expect(titlesWhileRegistering == [L10n.Settings.ConnectionSection.RegisterAsNewDevice.progress])
                #expect(viewModel.registerAsNewDeviceError == nil)
                #expect(!viewModel.isShowingRegisterAsNewDeviceError)
                #expect(!viewModel.isRegisteringAsNewDevice)
            }
        }
    }

    @Test func confirmingRegistersAsANewDevice() async throws {
        try await withTestWorld {
            try await withRegistrationIdentifierRestored {
                let server = makeServer(internalURL: "http://internal.example.com:8123", externalURL: nil)
                var registered = [Server]()
                let viewModel = ConnectionSettingsViewModel(
                    server: server,
                    ownership: RegistrationOwnership(register: { registered.append($0) }),
                    signIn: { _, _ in }
                )

                viewModel.confirmRegisteringAsNewDevice()
                #expect(viewModel.isRegisterAsNewDeviceConfirmationPresented)
                #expect(registered.isEmpty)

                viewModel.startRegisteringAsNewDevice()

                for _ in 0 ..< 100 where registered.isEmpty {
                    try await Task.sleep(for: .milliseconds(20))
                }
                #expect(registered == [server])
            }
        }
    }

    @Test func registeringAsANewDeviceReportsAFailure() async {
        await withTestWorld {
            await withRegistrationIdentifierRestored {
                let server = makeServer(internalURL: "http://internal.example.com:8123", externalURL: nil)
                let viewModel = ConnectionSettingsViewModel(
                    server: server,
                    ownership: RegistrationOwnership(register: { server in
                        throw ServerConnectionError.noActiveURL(server.info.name)
                    }),
                    signIn: { _, _ in }
                )

                await viewModel.registerAsNewDevice()

                #expect(viewModel.registerAsNewDeviceError is ServerConnectionError)
                #expect(viewModel.isShowingRegisterAsNewDeviceError)
                #expect(!viewModel.isRegisteringAsNewDevice)
            }
        }
    }

    @Test func theLoginPageIsShownWhileSigningInAndTakenDownAfter() async throws {
        try await withTestWorld {
            try await withRegistrationIdentifierRestored {
                let server = makeServer(internalURL: "http://internal.example.com:8123", externalURL: nil)
                let authDetails = try OnboardingAuthDetails(baseURL: URL(string: "http://internal.example.com:8123")!)
                let login = OnboardingAuthLoginViewModel(authDetails: authDetails)
                var shownWhileSigningIn: OnboardingAuthLoginViewModel?
                var viewModel: ConnectionSettingsViewModel!
                viewModel = ConnectionSettingsViewModel(
                    server: server,
                    ownership: RegistrationOwnership(register: { _ in }),
                    signIn: { _, present in
                        present(login)
                        shownWhileSigningIn = viewModel.login
                        present(nil)
                    }
                )

                await viewModel.registerAsNewDevice()

                #expect(shownWhileSigningIn === login)
                #expect(viewModel.login == nil)
            }
        }
    }

    @Test func cancellingTheLoginRegistersNothingAndReportsNothing() async {
        await withTestWorld {
            await withRegistrationIdentifierRestored {
                let server = makeServer(internalURL: "http://internal.example.com:8123", externalURL: nil)
                var registered = [Server]()
                let viewModel = ConnectionSettingsViewModel(
                    server: server,
                    ownership: RegistrationOwnership(register: { registered.append($0) }),
                    signIn: { _, _ in throw PMKError.cancelled }
                )

                await viewModel.registerAsNewDevice()

                #expect(registered.isEmpty)
                #expect(viewModel.registerAsNewDeviceError == nil)
                #expect(!viewModel.isShowingRegisterAsNewDeviceError)
                #expect(!viewModel.isRegisteringAsNewDevice)
            }
        }
    }

    @Test func failingToSignInRegistersNothingAndReportsTheFailure() async {
        await withTestWorld {
            await withRegistrationIdentifierRestored {
                let server = makeServer(internalURL: "http://internal.example.com:8123", externalURL: nil)
                var registered = [Server]()
                let viewModel = ConnectionSettingsViewModel(
                    server: server,
                    ownership: RegistrationOwnership(register: { registered.append($0) }),
                    signIn: { server, _ in throw ServerConnectionError.noActiveURL(server.info.name) }
                )

                await viewModel.registerAsNewDevice()

                #expect(registered.isEmpty)
                #expect(viewModel.registerAsNewDeviceError is ServerConnectionError)
                #expect(viewModel.isShowingRegisterAsNewDeviceError)
            }
        }
    }

    @Test func aServerStillAnotherDevicesOffersToReplaceItAndStopsOnceReplaced() async {
        await withTestWorld {
            await withRegistrationIdentifierRestored {
                let server = makeServer(internalURL: "http://internal.example.com:8123", externalURL: nil)
                let settings = Current.settingsStore
                settings.setRegistrationRecord(
                    RegistrationRecord(current: RegistrationIdentity(
                        deviceID: settings.integrationDeviceID,
                        ownerVendorID: "other-device"
                    )),
                    for: server.identifier
                )
                let viewModel = ConnectionSettingsViewModel(
                    server: server,
                    ownership: RegistrationOwnership(catchUp: { _ in }),
                    signIn: { _, _ in }
                )
                #expect(viewModel.isRegisteredByAnotherDevice)

                viewModel.confirmReplacingOldDevice()
                #expect(viewModel.isReplaceOldDeviceConfirmationPresented)
                viewModel.replaceOldDevice()

                #expect(!viewModel.isRegisteredByAnotherDevice)
                #expect(settings.currentRegistrationIdentity(for: server).ownerVendorID == "this-device")
            }
        }
    }

    @Test func aServerThisDeviceRegisteredOffersNothingToReplace() async {
        await withTestWorld {
            await withRegistrationIdentifierRestored {
                let server = makeServer(internalURL: "http://internal.example.com:8123", externalURL: nil)
                Current.settingsStore.setRegistrationRecord(
                    RegistrationRecord(current: RegistrationIdentity(
                        deviceID: Current.settingsStore.integrationDeviceID,
                        ownerVendorID: "this-device"
                    )),
                    for: server.identifier
                )

                let viewModel = ConnectionSettingsViewModel(server: server, signIn: { _, _ in })

                #expect(!viewModel.isRegisteredByAnotherDevice)
            }
        }
    }

    @Test func openingTheServerActivatesItInTheWindowItWasOpenedFrom() async {
        await withTestWorld {
            let server = makeServer(internalURL: "http://internal.example.com:8123", externalURL: nil)
            let viewModel = ConnectionSettingsViewModel(server: server)
            let windowCoordinator = MockAppCoordinator()
            let lastRegisteredCoordinator = MockAppCoordinator()
            Current.sceneManager.registerAppCoordinator(lastRegisteredCoordinator)

            viewModel.activateServer(on: windowCoordinator)

            #expect(windowCoordinator.activatedServers.map(\.identifier) == [server.identifier])
            #expect(lastRegisteredCoordinator.activatedServers.isEmpty)
        }
    }

    // MARK: - Local push, privacy, certificates and the signed-in user

    /// Swaps the app's local push manager for `fake` while `body` runs.
    private func withLocalPush(_ fake: FakeLocalPushManager, _ body: () async throws -> Void) async rethrows {
        let manager = Current.notificationManager
        let previous = manager.localPushManager
        manager.localPushManager = fake
        defer { manager.localPushManager = previous }
        try await body()
    }

    /// The status line follows every state the manager reports, refreshed when it reports a change.
    @Test func localPushStatusFollowsTheManager() async {
        let fake = FakeLocalPushManager()
        await withTestWorld {
            await withLocalPush(fake) {
                let viewModel = ConnectionSettingsViewModel(
                    server: makeServer(internalURL: nil, externalURL: "https://external.example.com")
                )
                let expectations: [(NotificationManagerLocalPushStatus, String)] = [
                    (.disabled, L10n.SettingsDetails.Notifications.LocalPush.Status.disabled),
                    (.unsupported, L10n.SettingsDetails.Notifications.LocalPush.Status.unsupported),
                    (.allowed(.unavailable), L10n.SettingsDetails.Notifications.LocalPush.Status.unavailable),
                    (.allowed(.establishing), L10n.SettingsDetails.Notifications.LocalPush.Status.establishing),
                ]
                for (status, text) in expectations {
                    fake.currentStatus = status
                    fake.notify()
                    #expect(viewModel.localPushStatus == text)
                }
                fake.currentStatus = .allowed(.available(received: 1234))
                fake.notify()
                #expect(viewModel.localPushStatus.contains("234"))
            }
        }
    }

    /// On the server's own Wi-Fi with local push on, Retry asks the manager to reconnect.
    @Test func retryingLocalPushAsksTheManagerOnTheHomeNetwork() async {
        let fake = FakeLocalPushManager()
        let connectivity = Current.connectivity
        let previousState = connectivity.currentNetworkState
        connectivity.currentNetworkState = { NetworkState(ssid: "Home Wi-Fi") }
        defer { connectivity.currentNetworkState = previousState }

        await withTestWorld {
            await withLocalPush(fake) {
                let server = makeServer(internalURL: "http://internal.example.com:8123", externalURL: nil)
                server.update {
                    $0.connection.isLocalPushEnabled = true
                    $0.connection.internalSSIDs = ["Home Wi-Fi"]
                }
                let viewModel = ConnectionSettingsViewModel(server: server)
                defer { Current.resetAPICache(for: [server.identifier]) }

                for _ in 0 ..< 1000 where !viewModel.canRetryLocalPush {
                    try? await Task.sleep(nanoseconds: 10_000_000)
                }
                #expect(viewModel.canRetryLocalPush)
                viewModel.retryLocalPush()
                #expect(fake.retriedServers == [server.identifier])
            }
        }
    }

    /// Changing the location or sensor privacy stores it on the server; the update it triggers is
    /// stopped by a background task runner that has no time left.
    @Test func privacyChoicesAreStoredOnTheServer() async {
        let previousRunner = Current.backgroundTask
        Current.backgroundTask = OutOfTimeBackgroundTaskRunner()
        defer { Current.backgroundTask = previousRunner }

        await withTestWorld {
            let server = makeServer(internalURL: nil, externalURL: nil)
            let viewModel = ConnectionSettingsViewModel(server: server)

            viewModel.updateLocationPrivacy(.zoneOnly)
            #expect(viewModel.locationPrivacy == .zoneOnly)
            #expect(server.info.setting(for: .locationPrivacy) == ServerLocationPrivacy.zoneOnly)

            viewModel.updateSensorPrivacy(.none)
            #expect(viewModel.sensorPrivacy == .none)
            #expect(server.info.setting(for: .sensorPrivacy) == ServerSensorPrivacy.none)
        }
    }

    /// A file the app cannot open for reading (here, not a file at all) fails the import.
    @Test func importingFromANonFileURLFails() async {
        await withTestWorld {
            let viewModel = ConnectionSettingsViewModel(server: makeServer(internalURL: nil, externalURL: nil))
            await viewModel.importCertificate(
                from: URL(string: "https://example.com/home.p12")!,
                password: "secret"
            )
            #expect(viewModel.certificateError != nil)
            #expect(!viewModel.isImportingCertificate)
        }
    }

    /// Removing the certificate clears it from the server; the keychain item stays while another
    /// server still uses it and is deleted (here: nothing to delete) once none does.
    @Test func removingTheCertificateKeepsItWhileAnotherServerUsesIt() async {
        await withTestWorld {
            let certificate = ClientCertificate(
                keychainIdentifier: "test-shared-\(UUID().uuidString)",
                displayName: "Shared"
            )
            let servers = FakeServerManager(initial: 0)
            Current.servers = servers
            let first = servers.add(identifier: "first", serverInfo: with(ServerInfo.fake()) {
                $0.connection.clientCertificate = certificate
            })
            let second = servers.add(identifier: "second", serverInfo: with(ServerInfo.fake()) {
                $0.connection.clientCertificate = certificate
            })
            defer { Current.resetAPICache(for: [first.identifier, second.identifier]) }

            let noCertificate = ConnectionSettingsViewModel(server: makeServer(internalURL: nil, externalURL: nil))
            noCertificate.removeCertificate()
            #expect(noCertificate.clientCertificate == nil)

            let firstModel = ConnectionSettingsViewModel(server: first)
            #expect(firstModel.clientCertificate == certificate)
            firstModel.removeCertificate()
            #expect(firstModel.clientCertificate == nil)
            #expect(first.info.connection.clientCertificate == nil)

            let secondModel = ConnectionSettingsViewModel(server: second)
            secondModel.removeCertificate()
            #expect(second.info.connection.clientCertificate == nil)
        }
    }
}

/// Reports whatever status a test sets and records retries, in place of the app's local push manager.
private final class FakeLocalPushManager: NotificationManagerLocalPushInterface {
    var currentStatus: NotificationManagerLocalPushStatus = .disabled
    private(set) var retriedServers: [Identifier<Server>] = []
    private var handlers: [(NotificationManagerLocalPushStatus) -> Void] = []

    func status(for server: Server) -> NotificationManagerLocalPushStatus {
        currentStatus
    }

    func addObserver(
        for server: Server,
        handler: @escaping (NotificationManagerLocalPushStatus) -> Void
    ) -> HACancellable {
        handlers.append(handler)
        return HAMockCancellable {}
    }

    func notify() {
        handlers.forEach { $0(currentStatus) }
    }

    func retryLocalPush(for server: Server?, reason: LocalPushRetryReason) {
        if let server { retriedServers.append(server.identifier) }
    }

    func scheduleAppOpenLocalPushRetries() {}
}

/// Fails every background task at once, without running the work it wraps.
private final class OutOfTimeBackgroundTaskRunner: HomeAssistantBackgroundTaskRunner {
    func callAsFunction<PromiseValue>(
        withName name: String,
        requiringAssertion: Bool,
        wrapping: (TimeInterval?) -> Promise<PromiseValue>
    ) -> Promise<PromiseValue> {
        Promise(error: BackgroundTaskError.outOfTime)
    }
}
