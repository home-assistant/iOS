import Foundation
import HAKit
import HAKit_PromiseKit
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
    /// Registers this device with a server from scratch, under `SettingsStore.registrationIdentity(for:)`.
    public typealias Register = (Server) async throws -> Void

    /// How long to wait for the devices a server has: a WebSocket command has no deadline of its own.
    static let deviceListTimeout: TimeInterval = 30

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
                  let owner = currentIdentity(of: server).ownerVendorID else { return false }
            return owner != vendorID
        }
    }

    /// Makes the registrations with `servers` this device's own, for when it replaced the device they came from, and
    /// with them the identifier it registers with from now on: logging in to one of these servers again then keeps
    /// its Home Assistant device instead of adding another.
    public func keepRegistrations(of servers: [Server]) {
        guard let vendorID = Current.device.identifierForVendor() else { return }
        let settings = Current.settingsStore
        recordIdentities()
        for server in servers {
            settings.updateRegistrationRecord(for: server.identifier) { record in
                record.current?.ownerVendorID = vendorID
                record.pending = nil
            }
        }
        settings.takeOverIntegrationDeviceID(for: vendorID)
    }

    /// Registers this device with each of `servers` as a new device, each under an identifier of its own. Their
    /// current registrations stay as they are on the servers, for whichever device still uses them. Returns the
    /// servers it could not register with, which keep the registration they had.
    public func registerAsNewDevice(_ servers: [Server]) async -> [Server: Error] {
        guard let vendorID = Current.device.identifierForVendor() else {
            return Dictionary(uniqueKeysWithValues: servers.map {
                ($0, RegistrationOwnershipError.noDeviceIdentifier as Error)
            })
        }

        let settings = Current.settingsStore
        recordIdentities()
        if settings.integrationDeviceIDOwnerVendorID != vendorID {
            // Every registration has its identity recorded by now, so this changes none of them, only what this
            // device registers with from here on, such as a server it is added to later.
            settings.adoptNewIntegrationDeviceID(ownedBy: vendorID)
        }

        var failures = [Server: Error]()
        for server in servers {
            settings.updateRegistrationRecord(for: server.identifier) { record in
                // An earlier attempt's identity is reused: the server may have registered it before the response
                // was lost, and registering it again replaces that registration rather than adding another.
                guard record.pending?.ownerVendorID != vendorID else { return }
                record.pending = RegistrationIdentity(
                    deviceID: settings.newIntegrationDeviceID(),
                    ownerVendorID: vendorID
                )
            }

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

        // Notifications reach a device through an action named after it, so the new registration can't take the
        // name of one it leaves on the server.
        let previousName = server.info.setting(for: .overrideDeviceName)
        let name = try await unusedDeviceName(for: server, on: api)
        if name != server.info.mobileAppDeviceName {
            server.update { $0.setSetting(value: name, for: .overrideDeviceName) }
        }

        do {
            try await api.register().asyncValue()
        } catch {
            // Keeping the registration it has after all must not rename it.
            server.update { $0.setSetting(value: previousName, for: .overrideDeviceName) }
            throw error
        }

        // The new registration has none of the sensors the previous one had.
        SensorRegistrationVersionStore.forgetRegistration(for: server.identifier)
        do {
            try await api.Connect(reason: .warm).asyncValue()
        } catch {
            // The registration is in place; whatever did not catch up is retried on the next connect.
            Current.Log.error("registered with \(server.identifier) as a new device, but failed to connect: \(error)")
        }
    }

    /// `name`, or the first of "`name` 2", "`name` 3" and on that no `mobile_app` device in `devices` has, other
    /// than the one registered as `deviceID`, which the registration replaces.
    static func unusedDeviceName(
        _ name: String,
        among devices: [DeviceRegistryEntry],
        replacing deviceID: String
    ) -> String {
        let taken = Set(devices.compactMap { device -> String? in
            let registrations = (device.identifiers ?? []).filter { $0.count == 2 && $0.first == "mobile_app" }
            guard !registrations.isEmpty, !registrations.contains(["mobile_app", deviceID]) else { return nil }
            return device.name?.lowercased()
        })

        var candidate = name
        var number = 1
        while taken.contains(candidate.lowercased()) {
            number += 1
            candidate = "\(name) \(number)"
        }
        return candidate
    }

    @MainActor
    private static func unusedDeviceName(for server: Server, on api: HomeAssistantAPI) async throws -> String {
        let request = api.connection.send(HATypedRequest<[DeviceRegistryEntry]>.configDeviceRegistryList())
        let devices: [DeviceRegistryEntry]
        do {
            devices = try await request.promise.asyncValue(timeout: deviceListTimeout)
        } catch {
            request.cancel()
            throw error
        }

        return unusedDeviceName(
            server.info.mobileAppDeviceName,
            among: devices,
            replacing: Current.settingsStore.registrationIdentity(for: server.identifier).deviceID
        )
    }

    private func currentIdentity(of server: Server) -> RegistrationIdentity {
        Current.settingsStore.registrationRecord(for: server.identifier).current
            ?? Current.settingsStore.integrationDeviceIdentity
    }

    /// Records the identity of each registration made before identities were recorded, which until now are
    /// `integrationDeviceID` and its owner, before either changes.
    private func recordIdentities() {
        let settings = Current.settingsStore
        let identity = settings.integrationDeviceIdentity
        for server in Current.servers.all {
            settings.updateRegistrationRecord(for: server.identifier) { record in
                if record.current == nil {
                    record.current = identity
                }
            }
        }
    }
}
