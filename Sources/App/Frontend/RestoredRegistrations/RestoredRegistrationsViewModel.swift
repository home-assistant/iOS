import Foundation
import Shared

/// Drives the prompt for the servers this device is registered with as another device, which it carries from the
/// backup it was restored from: it either registers itself with them as a new device, or keeps their registrations
/// because it replaced that device.
@MainActor
final class RestoredRegistrationsViewModel: ObservableObject {
    /// The servers still registered as another device. Registering narrows it to the ones that failed.
    @Published private(set) var servers: [Server]
    @Published private(set) var isRegistering = false
    /// Names the servers the last attempt could not register with.
    @Published private(set) var failureMessage: String?

    private let ownership: RegistrationOwnership
    /// Called once every server is settled, which closes the prompt.
    private let onFinished: () -> Void

    init(
        servers: [Server],
        ownership: RegistrationOwnership = RegistrationOwnership(),
        onFinished: @escaping () -> Void
    ) {
        self.servers = servers
        self.ownership = ownership
        self.onFinished = onFinished
    }

    var serverNames: String {
        ListFormatter.localizedString(byJoining: servers.map(\.info.name))
    }

    var registerTitle: String {
        isRegistering ? L10n.RestoredRegistrations.progress : L10n.RestoredRegistrations.register
    }

    func startRegistration() {
        Task {
            await registerAsNewDevice()
        }
    }

    func registerAsNewDevice() async {
        isRegistering = true
        failureMessage = nil
        let failures = await ownership.registerAsNewDevice(servers)
        isRegistering = false

        let failed = servers.filter { failures[$0] != nil }
        if failed.isEmpty {
            onFinished()
        } else {
            servers = failed
            failureMessage = L10n.RestoredRegistrations.failure(serverNames)
        }
    }

    func keepRegistrations() {
        ownership.keepRegistrations(of: servers)
        onFinished()
    }
}
