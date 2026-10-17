import Foundation
import PromiseKit

/// Settles the `mobile_app` registrations a device only has because it was set up from a backup of another one.
///
/// A backup carries every server along with its registration, so the restored device reports to Home Assistant as
/// the device the backup came from. While both are in use, their sensors, location and notifications land on one
/// Home Assistant device, and logging in again on either replaces the registration the other one relies on. Each
/// registration belongs to the device whose identifier it was made with, which lets the restored device tell. The
/// user then decides: this device took over from the other one and keeps the registrations, or it registers itself
/// as a new device and leaves them to the other one.
public struct RegistrationOwnership {
    /// Registers this device with a server from scratch, under the current `integrationDeviceID`.
    public typealias Register = (Server) async throws -> Void

    private let register: Register

    public init(register: @escaping Register = RegistrationOwnership.registerWithServer(_:)) {
        self.register = register
    }

    /// The servers whose registration belongs to another device. Always empty on the Mac, which keeps the identifier
    /// it registered with under Mac Catalyst on purpose, and while the device has no vendor identifier to compare.
    /// A server waiting to be signed in to again after a recovery is left out until it can be registered with.
    public func serversRegisteredByAnotherDevice() -> [Server] {
        guard !Current.isCatalyst, let vendorID = Current.device.identifierForVendor() else { return [] }
        return Current.servers.all.filter { server in
            guard !server.info.requiresReauthenticationAfterMirrorRestore,
                  let owner = owner(of: server) else { return false }
            return owner != vendorID
        }
    }

    /// Makes the registrations with `servers` this device's own, for when it replaced the device they came from, and
    /// with them the identifier it registers with from now on: logging in to one of these servers again then keeps
    /// its Home Assistant device instead of adding another.
    public func keepRegistrations(of servers: [Server]) {
        guard let vendorID = Current.device.identifierForVendor() else { return }
        recordOwners()
        for server in servers {
            Current.settingsStore.setRegistrationOwnerVendorID(vendorID, for: server.identifier)
        }
        Current.settingsStore.takeOverIntegrationDeviceID(for: vendorID)
    }

    /// Registers this device with each of `servers` as a new device. Their current registrations stay as they are
    /// on the servers, for whichever device still uses them. Returns the servers it could not register with, which
    /// keep the registration they had.
    public func registerAsNewDevice(_ servers: [Server]) async -> [Server: Error] {
        guard let vendorID = Current.device.identifierForVendor() else {
            return Dictionary(uniqueKeysWithValues: servers.map {
                ($0, RegistrationOwnershipError.noDeviceIdentifier as Error)
            })
        }

        recordOwners()
        // The current identifier is another device's, or already behind one of this device's registrations: a
        // registration under it would replace that one rather than add a device.
        Current.settingsStore.adoptNewIntegrationDeviceID(ownedBy: vendorID)

        var failures = [Server: Error]()
        for server in servers {
            do {
                try await register(server)
            } catch {
                Current.Log.error("failed to register with \(server.identifier) as a new device: \(error)")
                failures[server] = error
            }
        }
        return failures
    }

    /// Registers with `server` and brings the new registration up to date: its sensors, the device `get_config`
    /// reports, and their current states.
    @MainActor
    public static func registerWithServer(_ server: Server) async throws {
        guard let api = Current.api(for: server) else {
            throw ServerConnectionError.noActiveURL(server.info.name)
        }

        try await api.register().asyncValue()

        // The new registration has none of the sensors the previous one had.
        SensorRegistrationVersionStore.forgetRegistration(for: server.identifier)
        do {
            try await api.Connect(reason: .warm).asyncValue()
        } catch {
            // The registration is in place; whatever did not catch up is retried on the next connect.
            Current.Log.error("registered with \(server.identifier) as a new device, but failed to connect: \(error)")
        }
    }

    private func owner(of server: Server) -> String? {
        Current.settingsStore.registrationOwnerVendorID(for: server.identifier)
            ?? Current.settingsStore.integrationDeviceIDOwnerVendorID
    }

    /// Records who owns each registration made before owners were recorded, which until now is whoever owns the
    /// current identifier, before that identifier or its owner changes.
    private func recordOwners() {
        let settings = Current.settingsStore
        guard let owner = settings.integrationDeviceIDOwnerVendorID else { return }
        for server in Current.servers.all where settings.registrationOwnerVendorID(for: server.identifier) == nil {
            settings.setRegistrationOwnerVendorID(owner, for: server.identifier)
        }
    }
}
