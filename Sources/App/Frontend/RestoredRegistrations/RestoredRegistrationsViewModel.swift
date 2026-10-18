import Foundation
import Shared
import UIKit

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
    /// Set once every server is settled, which closes the prompt.
    @Published private(set) var isFinished = false

    private let ownership: RegistrationOwnership

    init(servers: [Server], ownership: RegistrationOwnership = RegistrationOwnership()) {
        self.servers = servers
        self.ownership = ownership
    }

    var serverNames: String {
        ListFormatter.localizedString(byJoining: servers.map(\.info.name))
    }

    func registerAsNewDevice() async {
        isRegistering = true
        failureMessage = nil
        let failures = await ownership.registerAsNewDevice(servers)
        isRegistering = false

        let failed = servers.filter { failures[$0] != nil }
        if failed.count < servers.count {
            // The new registrations have no location until the next update, so send one now.
            HomeAssistantAPI.manuallyUpdate(
                applicationState: UIApplication.shared.applicationState,
                type: .programmatic
            ).cauterize()
        }

        if failed.isEmpty {
            isFinished = true
        } else {
            servers = failed
            failureMessage = L10n.RestoredRegistrations.failure(serverNames)
        }
    }

    func keepRegistrations() {
        ownership.keepRegistrations(of: servers)
        isFinished = true
    }
}
