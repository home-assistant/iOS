import Foundation
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import SwiftUI
import Testing
import UIKit

/// The launch screen for a device restored from another one's backup: signing in and registering anew, skipping and
/// retrying what did not go through, or replacing the other device.
// Serialized: the tests swap `Current` and the app group's stored registration identifier.
@Suite(.serialized)
@MainActor
struct RestoredRegistrationsViewModelTests {
    private struct RegisterFailure: Error {}
    private struct SignInFailure: Error {}

    /// A sign-in that presents a login page for `server` and resolves right away.
    private static func signIn(_ signedIn: @escaping (Server) -> Void) -> ServerReauthentication.SignIn {
        { server, _ in signedIn(server) }
    }

    /// Runs `body` on "this-device", carrying a registration identifier from "other-device".
    private func withRestoredDevice(_ body: (FakeServerManager) async throws -> Void) async rethrows {
        let prefs = Current.settingsStore.prefs
        let previousServers = Current.servers
        let previousVendorID = Current.device.identifierForVendor
        let previousIsCatalyst = Current.isCatalyst
        let keys = [
            SettingsStore.integrationDeviceIDKey,
            SettingsStore.integrationDeviceIDOwnerKey,
            SettingsStore.registrationRecordsKey,
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

    /// Counts how often the prompt asked to be closed.
    private final class FinishCounter {
        var count = 0
    }

    /// Lays the prompt out in a window of its own, which is what makes SwiftUI evaluate its body.
    private func render(_ viewModel: RestoredRegistrationsViewModel) {
        let controller = UIHostingController(rootView: RestoredRegistrationsView(viewModel: viewModel))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 640))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        window.isHidden = true
        window.rootViewController = nil
    }

    @Test func listsEveryServerByName() async {
        await withRestoredDevice { servers in
            let viewModel = RestoredRegistrationsViewModel(
                servers: [addServer(named: "Home", to: servers), addServer(named: "Cabin", to: servers)],
                onFinished: {}
            )

            #expect(viewModel.serverNames == ListFormatter.localizedString(byJoining: ["Home", "Cabin"]))
        }
    }

    @Test func settingUpSignsInToEachServerThenRegistersAndClosesTheScreen() async {
        await withRestoredDevice { servers in
            let restored = [addServer(named: "Home", to: servers), addServer(named: "Cabin", to: servers)]
            let finished = FinishCounter()
            var steps = [String]()
            var titlesWhileRegistering = [String]()
            var viewModel: RestoredRegistrationsViewModel!
            viewModel = RestoredRegistrationsViewModel(
                servers: restored,
                ownership: RegistrationOwnership(register: { server in
                    titlesWhileRegistering.append(viewModel.newDeviceTitle)
                    steps.append("register \(server.info.name)")
                }),
                signIn: Self.signIn { steps.append("sign in \($0.info.name)") },
                onFinished: { finished.count += 1 }
            )
            #expect(viewModel.newDeviceTitle == L10n.RestoredRegistrations.newDevice)

            await viewModel.setUpAsNewDevice()

            #expect(steps == ["sign in Home", "register Home", "sign in Cabin", "register Cabin"])
            #expect(titlesWhileRegistering == Array(repeating: L10n.RestoredRegistrations.settingUp, count: 2))
            #expect(finished.count == 1)
            #expect(viewModel.failureMessage == nil)
            #expect(!viewModel.isRegistering)
            #expect(viewModel.login == nil)
        }
    }

    @Test func theLoginPageIsShownWhileSigningInAndTakenDownAfter() async throws {
        try await withRestoredDevice { servers in
            let server = addServer(named: "Home", to: servers)
            let authDetails = try OnboardingAuthDetails(baseURL: URL(string: "http://homeassistant.local:8123")!)
            let login = OnboardingAuthLoginViewModel(authDetails: authDetails)
            var shownWhileSigningIn: OnboardingAuthLoginViewModel?
            var viewModel: RestoredRegistrationsViewModel!
            viewModel = RestoredRegistrationsViewModel(
                servers: [server],
                ownership: RegistrationOwnership(register: { _ in }),
                signIn: { _, present in
                    present(login)
                    shownWhileSigningIn = viewModel.login
                    present(nil)
                },
                onFinished: {}
            )

            await viewModel.setUpAsNewDevice()

            #expect(shownWhileSigningIn === login)
            #expect(viewModel.login == nil)
        }
    }

    @Test func theNewDeviceButtonStartsSettingUp() async throws {
        try await withRestoredDevice { servers in
            let finished = FinishCounter()
            let viewModel = RestoredRegistrationsViewModel(
                servers: [addServer(named: "Home", to: servers)],
                ownership: RegistrationOwnership(register: { _ in }),
                signIn: Self.signIn { _ in },
                onFinished: { finished.count += 1 }
            )

            viewModel.startSettingUpAsNewDevice()

            for _ in 0 ..< 100 where finished.count == 0 {
                try await Task.sleep(for: .milliseconds(20))
            }
            #expect(finished.count == 1)
        }
    }

    /// A login the user cancels is left for the next launch, and the servers after it are still gone through.
    @Test func cancellingALoginSkipsThatServerAndGoesOnToTheNext() async {
        await withRestoredDevice { servers in
            let home = addServer(named: "Home", to: servers)
            let cabin = addServer(named: "Cabin", to: servers)
            let finished = FinishCounter()
            var registered = [Server]()
            let viewModel = RestoredRegistrationsViewModel(
                servers: [home, cabin],
                ownership: RegistrationOwnership(register: { server in
                    registered.append(server)
                    // What the server's answer leaves behind: the registration is now the pending identity's.
                    Current.settingsStore.updateRegistrationRecord(for: server.identifier) { record in
                        record.current = record.pending
                        record.pending = nil
                    }
                }),
                signIn: { server, _ in
                    if server == home {
                        throw PMKError.cancelled
                    }
                },
                onFinished: { finished.count += 1 }
            )

            await viewModel.setUpAsNewDevice()

            #expect(registered == [cabin])
            #expect(viewModel.servers == [home])
            #expect(viewModel.failureMessage == nil)
            // Nothing failed, so the screen closes; the skipped server is asked about again on the next launch.
            #expect(finished.count == 1)
            #expect(RegistrationOwnership().serversRegisteredByAnotherDevice() == [home])
        }
    }

    @Test func serversThatFailedToSignInOrRegisterStayToTryAgain() async {
        await withRestoredDevice { servers in
            let home = addServer(named: "Home", to: servers)
            let cabin = addServer(named: "Cabin", to: servers)
            let lake = addServer(named: "Lake", to: servers)
            let finished = FinishCounter()
            let viewModel = RestoredRegistrationsViewModel(
                servers: [home, cabin, lake],
                ownership: RegistrationOwnership(register: { server in
                    if server == cabin {
                        throw RegisterFailure()
                    }
                }),
                signIn: { server, _ in
                    if server == lake {
                        throw SignInFailure()
                    }
                },
                onFinished: { finished.count += 1 }
            )

            await viewModel.setUpAsNewDevice()

            #expect(viewModel.servers == [cabin, lake])
            #expect(viewModel.failureMessage == L10n.RestoredRegistrations.failure(viewModel.serverNames))
            #expect(finished.count == 0)
            #expect(!viewModel.isRegistering)
            // The screen stays up, now naming the servers to try again with.
            render(viewModel)
        }
    }

    @Test func replacingTheOldDeviceIsConfirmedFirst() async {
        await withRestoredDevice { servers in
            let finished = FinishCounter()
            let kept = [addServer(named: "Home", to: servers), addServer(named: "Cabin", to: servers)]
            var caughtUp = [Server]()
            let viewModel = RestoredRegistrationsViewModel(
                servers: kept,
                ownership: RegistrationOwnership(catchUp: { caughtUp.append($0) }),
                onFinished: { finished.count += 1 }
            )

            viewModel.confirmReplacingOldDevice()
            #expect(viewModel.isReplaceConfirmationPresented)
            #expect(finished.count == 0)
            #expect(caughtUp.isEmpty)

            viewModel.replaceOldDevice()

            #expect(finished.count == 1)
            #expect(RegistrationOwnership().serversRegisteredByAnotherDevice().isEmpty)
            #expect(caughtUp == kept)
        }
    }
}
