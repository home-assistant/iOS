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

    /// Sets up as a new device, going on at every hand-off between servers as a user tapping Continue would.
    private func setUpGoingOn(_ viewModel: RestoredRegistrationsViewModel) async {
        var finished = false
        var resumed = Set<Int>()
        Task { @MainActor in
            await viewModel.setUpAsNewDevice()
            finished = true
        }
        while !finished {
            if let next = viewModel.nextServer, !resumed.contains(next.position) {
                resumed.insert(next.position)
                next.goOn()
            }
            try? await Task.sleep(for: .milliseconds(5))
        }
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

            await setUpGoingOn(viewModel)

            #expect(steps == ["sign in Home", "register Home", "sign in Cabin", "register Cabin"])
            #expect(titlesWhileRegistering == Array(repeating: L10n.RestoredRegistrations.settingUp, count: 2))
            #expect(finished.count == 1)
            #expect(restored.map(viewModel.state(of:)) == [.done, .done])
            #expect(!viewModel.isRegistering)
            #expect(viewModel.login == nil)
        }
    }

    @Test func theLoginPageIsShownWhileSigningInAndTakenDownAfter() async throws {
        try await withRestoredDevice { servers in
            let server = addServer(named: "Home", to: servers)
            let authDetails = try OnboardingAuthDetails(baseURL: URL(string: "http://homeassistant.local:8123")!)
            let login = OnboardingAuthLoginViewModel(authDetails: authDetails)
            var shownWhileSigningIn: RestoredRegistrationsViewModel.Login?
            var stateWhileSigningIn: RestoredRegistrationsViewModel.SetupState?
            var viewModel: RestoredRegistrationsViewModel!
            viewModel = RestoredRegistrationsViewModel(
                servers: [server],
                ownership: RegistrationOwnership(register: { _ in }),
                signIn: { _, present in
                    present(login)
                    shownWhileSigningIn = viewModel.login
                    stateWhileSigningIn = viewModel.state(of: server)
                    present(nil)
                },
                onFinished: {}
            )

            await viewModel.setUpAsNewDevice()

            #expect(shownWhileSigningIn?.viewModel === login)
            #expect(shownWhileSigningIn?.server == server)
            #expect(shownWhileSigningIn?.position == 1)
            #expect(shownWhileSigningIn?.count == 1)
            #expect(stateWhileSigningIn == .signingIn)
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

    /// Setting up is one decision for every server: cancelling a login ends the run, and that server and the ones
    /// after it are asked about again on the next launch.
    @Test func cancellingALoginEndsTheRunAndLeavesTheRestForTheNextLaunch() async {
        await withRestoredDevice { servers in
            let home = addServer(named: "Home", to: servers)
            let cabin = addServer(named: "Cabin", to: servers)
            let lake = addServer(named: "Lake", to: servers)
            let finished = FinishCounter()
            var registered = [Server]()
            var signedIn = [Server]()
            let viewModel = RestoredRegistrationsViewModel(
                servers: [home, cabin, lake],
                ownership: RegistrationOwnership(register: { server in
                    registered.append(server)
                    Current.settingsStore.updateRegistrationRecord(for: server.identifier) { record in
                        record.current = record.pending
                        record.pending = nil
                    }
                }),
                signIn: { server, _ in
                    signedIn.append(server)
                    if server == cabin {
                        throw PMKError.cancelled
                    }
                },
                onFinished: { finished.count += 1 }
            )

            await setUpGoingOn(viewModel)

            #expect(signedIn == [home, cabin])
            #expect(registered == [home])
            #expect(viewModel.state(of: home) == .done)
            #expect(viewModel.state(of: cabin) == .skipped)
            #expect(viewModel.state(of: lake) == .skipped)
            // Nothing failed, so the screen closes; the next launch asks about the two left.
            #expect(finished.count == 1)
            #expect(RegistrationOwnership().serversRegisteredByAnotherDevice() == [cabin, lake])
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

            await setUpGoingOn(viewModel)

            #expect(viewModel.state(of: home) == .done)
            #expect(viewModel.state(of: cabin) == .failed(RegisterFailure().localizedDescription))
            #expect(viewModel.state(of: lake) == .failed(SignInFailure().localizedDescription))
            #expect(viewModel.hasFailures)
            #expect(viewModel.newDeviceTitle == L10n.RestoredRegistrations.tryAgain)
            #expect(finished.count == 0)
            #expect(!viewModel.isRegistering)
            // The screen stays up, showing where each server stands.
            render(viewModel)
        }
    }

    /// Trying again goes through the servers that are not set up yet, and leaves the ones that are alone.
    @Test func tryingAgainOnlyRetriesWhatIsNotSetUp() async {
        await withRestoredDevice { servers in
            let home = addServer(named: "Home", to: servers)
            let cabin = addServer(named: "Cabin", to: servers)
            let finished = FinishCounter()
            var failCabin = true
            var registered = [Server]()
            let viewModel = RestoredRegistrationsViewModel(
                servers: [home, cabin],
                ownership: RegistrationOwnership(register: { server in
                    registered.append(server)
                    if server == cabin, failCabin {
                        throw RegisterFailure()
                    }
                }),
                signIn: { _, _ in },
                onFinished: { finished.count += 1 }
            )

            await setUpGoingOn(viewModel)
            #expect(finished.count == 0)

            failCabin = false
            await setUpGoingOn(viewModel)

            #expect(registered == [home, cabin, cabin])
            #expect(viewModel.state(of: home) == .done)
            #expect(viewModel.state(of: cabin) == .done)
            #expect(finished.count == 1)
        }
    }

    /// The login page says which server it is for and where it stands in the run.
    @Test func eachLoginIsNumberedAmongTheServersBeingSetUp() async {
        await withRestoredDevice { servers in
            let home = addServer(named: "Home", to: servers)
            let cabin = addServer(named: "Cabin", to: servers)
            var logins = [String]()
            var viewModel: RestoredRegistrationsViewModel!
            viewModel = RestoredRegistrationsViewModel(
                servers: [home, cabin],
                ownership: RegistrationOwnership(register: { _ in }),
                signIn: { server, present in
                    let authDetails =
                        try OnboardingAuthDetails(baseURL: URL(string: "http://homeassistant.local:8123")!)
                    present(OnboardingAuthLoginViewModel(authDetails: authDetails))
                    if let login = viewModel.login {
                        logins.append("\(login.server.info.name) \(login.position)/\(login.count)")
                    }
                    _ = server
                    present(nil)
                },
                onFinished: {}
            )

            await setUpGoingOn(viewModel)

            #expect(logins == ["Home 1/2", "Cabin 2/2"])
        }
    }

    /// Between two servers the sheet hands off: it says what became of the one just finished and which one's login
    /// comes next, and waits for the user before opening it.
    @Test func theHandOffBetweenServersWaitsForTheUser() async throws {
        try await withRestoredDevice { servers in
            let home = addServer(named: "Home", to: servers)
            let cabin = addServer(named: "Cabin", to: servers)
            var signedIn = [Server]()
            let viewModel = RestoredRegistrationsViewModel(
                servers: [home, cabin],
                ownership: RegistrationOwnership(register: { _ in }),
                signIn: { server, _ in signedIn.append(server) },
                onFinished: {}
            )

            var finished = false
            Task { @MainActor in
                await viewModel.setUpAsNewDevice()
                finished = true
            }
            for _ in 0 ..< 200 where viewModel.nextServer == nil {
                try await Task.sleep(for: .milliseconds(5))
            }
            let next = try #require(viewModel.nextServer)

            #expect(next.previous == home)
            #expect(next.previousState == .done)
            #expect(next.next == cabin)
            #expect(next.position == 2)
            #expect(next.count == 2)
            #expect(signedIn == [home])
            #expect(viewModel.state(of: cabin) == .waiting)
            #expect(!finished)

            next.goOn()
            for _ in 0 ..< 200 where !finished {
                try await Task.sleep(for: .milliseconds(5))
            }
            #expect(signedIn == [home, cabin])
            #expect(viewModel.state(of: cabin) == .done)
            #expect(viewModel.sheet == nil)
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
