import Foundation
@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing
import UIKit

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

    @Test func registeringWithEveryServerClosesThePrompt() async {
        await withRestoredDevice { servers in
            let restored = [addServer(named: "Home", to: servers), addServer(named: "Cabin", to: servers)]
            let finished = FinishCounter()
            var registered = [Server]()
            var titlesWhileRegistering = [String]()
            var viewModel: RestoredRegistrationsViewModel!
            viewModel = RestoredRegistrationsViewModel(
                servers: restored,
                ownership: RegistrationOwnership(register: { server in
                    titlesWhileRegistering.append(viewModel.registerTitle)
                    registered.append(server)
                }),
                onFinished: { finished.count += 1 }
            )
            #expect(viewModel.registerTitle == L10n.RestoredRegistrations.register)

            await viewModel.registerAsNewDevice()

            #expect(registered == restored)
            #expect(titlesWhileRegistering == Array(repeating: L10n.RestoredRegistrations.progress, count: 2))
            #expect(finished.count == 1)
            #expect(viewModel.failureMessage == nil)
            #expect(!viewModel.isRegistering)
        }
    }

    @Test func theRegisterButtonStartsRegistering() async throws {
        try await withRestoredDevice { servers in
            let finished = FinishCounter()
            let viewModel = RestoredRegistrationsViewModel(
                servers: [addServer(named: "Home", to: servers)],
                ownership: RegistrationOwnership(register: { _ in }),
                onFinished: { finished.count += 1 }
            )

            viewModel.startRegistration()

            for _ in 0 ..< 100 where finished.count == 0 {
                try await Task.sleep(for: .milliseconds(20))
            }
            #expect(finished.count == 1)
        }
    }

    @Test func serversThatFailedStayToTryAgain() async {
        await withRestoredDevice { servers in
            let home = addServer(named: "Home", to: servers)
            let cabin = addServer(named: "Cabin", to: servers)
            let finished = FinishCounter()
            let viewModel = RestoredRegistrationsViewModel(
                servers: [home, cabin],
                ownership: RegistrationOwnership(register: { server in
                    if server == cabin {
                        throw RegisterFailure()
                    }
                }),
                onFinished: { finished.count += 1 }
            )

            await viewModel.registerAsNewDevice()

            #expect(viewModel.servers == [cabin])
            #expect(viewModel.failureMessage == L10n.RestoredRegistrations.failure(viewModel.serverNames))
            #expect(finished.count == 0)
            #expect(!viewModel.isRegistering)
            // The prompt stays up, now naming the server to try again with.
            render(viewModel)
        }
    }

    @Test func keepingTheRegistrationsClosesThePromptForGood() async {
        await withRestoredDevice { servers in
            let finished = FinishCounter()
            let viewModel = RestoredRegistrationsViewModel(
                servers: [addServer(named: "Home", to: servers), addServer(named: "Cabin", to: servers)],
                onFinished: { finished.count += 1 }
            )

            viewModel.keepRegistrations()

            #expect(finished.count == 1)
            #expect(RegistrationOwnership().serversRegisteredByAnotherDevice().isEmpty)
        }
    }
}
