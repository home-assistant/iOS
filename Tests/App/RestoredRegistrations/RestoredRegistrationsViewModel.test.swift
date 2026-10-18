import Foundation
@testable import HomeAssistant
@testable import Shared
import Testing

/// The launch prompt for a device restored from another one's backup: registering anew, retrying what failed, or
/// keeping the registrations.
// Serialized: the tests swap `Current` and the app group's stored registration identifier.
@Suite(.serialized)
@MainActor
struct RestoredRegistrationsViewModelTests {
    private struct RegisterFailure: Error {}

    /// Runs `body` on "this-device", carrying a registration identifier from "other-device".
    private func withRestoredDevice(_ body: (FakeServerManager) async throws -> Void) async rethrows {
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
        prefs.set("other-device", forKey: SettingsStore.integrationDeviceIDKey)
        try await body(servers)
    }

    /// A server without any URL, so the update sent after registering has nowhere to go.
    private func addServer(named name: String, to servers: FakeServerManager) -> Server {
        let info = ServerInfo(
            name: name,
            connection: .init(
                externalURL: nil,
                internalURL: nil,
                cloudhookURL: nil,
                remoteUIURL: nil,
                webhookID: "webhook-\(name)",
                webhookSecret: nil,
                internalSSIDs: nil,
                internalHardwareAddresses: nil,
                isLocalPushEnabled: false,
                securityExceptions: .init(),
                connectionAccessSecurityLevel: .undefined
            ),
            token: .init(accessToken: "token", refreshToken: "refresh", expiration: Date()),
            version: "2024.1"
        )
        return servers.add(identifier: .init(rawValue: name), serverInfo: info)
    }

    @Test func listsEveryServerByName() async {
        await withRestoredDevice { servers in
            let viewModel = RestoredRegistrationsViewModel(servers: [
                addServer(named: "Home", to: servers),
                addServer(named: "Cabin", to: servers),
            ])

            #expect(viewModel.serverNames == ListFormatter.localizedString(byJoining: ["Home", "Cabin"]))
        }
    }

    @Test func registeringWithEveryServerClosesThePrompt() async {
        await withRestoredDevice { servers in
            let restored = [addServer(named: "Home", to: servers), addServer(named: "Cabin", to: servers)]
            var registered = [Server]()
            let viewModel = RestoredRegistrationsViewModel(
                servers: restored,
                ownership: RegistrationOwnership(register: { server in
                    registered.append(server)
                })
            )

            await viewModel.registerAsNewDevice()

            #expect(registered == restored)
            #expect(viewModel.isFinished)
            #expect(viewModel.failureMessage == nil)
            #expect(!viewModel.isRegistering)
        }
    }

    @Test func serversThatFailedStayToTryAgain() async {
        await withRestoredDevice { servers in
            let home = addServer(named: "Home", to: servers)
            let cabin = addServer(named: "Cabin", to: servers)
            let viewModel = RestoredRegistrationsViewModel(
                servers: [home, cabin],
                ownership: RegistrationOwnership(register: { server in
                    if server == cabin {
                        throw RegisterFailure()
                    }
                })
            )

            await viewModel.registerAsNewDevice()

            #expect(viewModel.servers == [cabin])
            #expect(viewModel.failureMessage == L10n.RestoredRegistrations.failure(viewModel.serverNames))
            #expect(!viewModel.isFinished)
            #expect(!viewModel.isRegistering)
        }
    }

    @Test func keepingTheRegistrationsClosesThePromptForGood() async {
        await withRestoredDevice { servers in
            let viewModel = RestoredRegistrationsViewModel(servers: [
                addServer(named: "Home", to: servers),
                addServer(named: "Cabin", to: servers),
            ])

            viewModel.keepRegistrations()

            #expect(viewModel.isFinished)
            #expect(RegistrationOwnership().serversRegisteredByAnotherDevice().isEmpty)
        }
    }
}
