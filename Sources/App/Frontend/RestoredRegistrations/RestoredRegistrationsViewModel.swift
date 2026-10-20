import Foundation
import PromiseKit
import Shared

/// Drives the screen for the servers this device is registered with as another device, which it carries from the
/// backup it was restored from: it signs in to each again and registers as a new device, or replaces the other
/// device and keeps its registrations.
@MainActor
final class RestoredRegistrationsViewModel: ObservableObject {
    /// The servers still registered as another device. Setting up narrows it to the ones not settled.
    @Published private(set) var servers: [Server]
    @Published private(set) var isRegistering = false
    /// Names the servers the last attempt could not set up.
    @Published private(set) var failureMessage: String?
    /// The login page of the server being signed in to, while there is one.
    @Published var login: OnboardingAuthLoginViewModel?
    @Published var isReplaceConfirmationPresented = false

    private let ownership: RegistrationOwnership
    private let signIn: ServerReauthentication.SignIn
    /// Called once every server is settled or left for the next launch, which closes the screen.
    private let onFinished: () -> Void

    init(
        servers: [Server],
        ownership: RegistrationOwnership = RegistrationOwnership(),
        signIn: @escaping ServerReauthentication.SignIn = ServerReauthentication.signIn(to:presenting:),
        onFinished: @escaping () -> Void
    ) {
        self.servers = servers
        self.ownership = ownership
        self.signIn = signIn
        self.onFinished = onFinished
    }

    var serverNames: String {
        ListFormatter.localizedString(byJoining: servers.map(\.info.name))
    }

    var newDeviceTitle: String {
        isRegistering ? L10n.RestoredRegistrations.settingUp : L10n.RestoredRegistrations.newDevice
    }

    func startSettingUpAsNewDevice() {
        Task {
            await setUpAsNewDevice()
        }
    }

    /// Signs in to each server in turn and registers with it as a new device. A login the user cancels leaves that
    /// server as it is, to be asked about again on the next launch. A server that could not be set up stays on
    /// screen to try again.
    func setUpAsNewDevice() async {
        isRegistering = true
        failureMessage = nil
        defer { isRegistering = false }

        var failed = [Server]()
        var unsettled = [Server]()
        for server in servers {
            do {
                try await signIn(server) { [weak self] login in
                    self?.login = login
                }
                if let error = await ownership.registerAsNewDevice([server])[server] {
                    throw error
                }
            } catch let error as PMKError where error.isCancelled {
                Current.Log.info("login to \(server.identifier) cancelled; its registration is left for now")
                unsettled.append(server)
            } catch {
                Current.Log.error("failed to set up \(server.identifier) as a new device: \(error)")
                failed.append(server)
                unsettled.append(server)
            }
        }

        servers = unsettled
        if failed.isEmpty {
            onFinished()
        } else {
            failureMessage = L10n.RestoredRegistrations.failure(
                ListFormatter.localizedString(byJoining: failed.map(\.info.name))
            )
        }
    }

    func confirmReplacingOldDevice() {
        isReplaceConfirmationPresented = true
    }

    func replaceOldDevice() {
        ownership.keepRegistrations(of: servers)
        onFinished()
    }
}
