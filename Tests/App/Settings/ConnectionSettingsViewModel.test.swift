import Foundation
@testable import HomeAssistant
import PromiseKit
@testable import Shared
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
@Suite(.serialized)
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
            #expect(viewModel.externalURL == L10n.Settings.ConnectionSection.HomeAssistantCloud.title)
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
        ]
        let previousValues = keys.map { prefs.object(forKey: $0) }
        defer {
            Current.device.identifierForVendor = previousVendorID
            for (key, value) in zip(keys, previousValues) {
                prefs.set(value, forKey: key)
            }
        }
        Current.device.identifierForVendor = { "this-device" }
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
}
