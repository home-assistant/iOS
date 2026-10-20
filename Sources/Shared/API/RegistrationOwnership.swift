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
    /// Brings a registration up to date with this device: its registration data, such as its push token, and its
    /// sensors.
    public typealias CatchUp = (Server) -> Void
    /// The webhook request types that report this device to a server.
    static let reportingRequestTypes: Set<String> = ["update_location", "update_sensor_states", "register_sensor"]

    /// How long to wait for the devices a server has: a WebSocket command has no deadline of its own.
    static let deviceListTimeout: TimeInterval = 30
    /// How long to wait for a new registration to catch up before leaving it to carry on in the background, such as
    /// sensor updates that fall back to a background session while the network is down. Non-private for tests.
    static var reconnectTimeout: TimeInterval = 30

    private static let inFlightLock = NSLock()
    /// The registration under way with each server, for a second attempt to join rather than start another.
    private static var inFlight = [Identifier<Server>: Task<Void, Error>]()

    private let register: Register
    private let catchUp: CatchUp

    public init(
        register: @escaping Register = RegistrationOwnership.registerWithServer(_:),
        catchUp: @escaping CatchUp = RegistrationOwnership.catchUpWithServer(_:)
    ) {
        self.register = register
        self.catchUp = catchUp
    }

    /// The servers whose registration belongs to another device. Always empty on the Mac, which keeps the identifier
    /// it registered with under Mac Catalyst on purpose, and while the device has no vendor identifier to compare.
    /// A server waiting to be signed in to again after a recovery is left out until it can be registered with.
    public func serversRegisteredByAnotherDevice() -> [Server] {
        Current.servers.all.filter(isRegisteredByAnotherDevice)
    }

    /// Whether the registration with `server` belongs to another device, as `serversRegisteredByAnotherDevice()`
    /// tells.
    public func isRegisteredByAnotherDevice(_ server: Server) -> Bool {
        !server.info.requiresReauthenticationAfterMirrorRestore
            && belongsToAnotherDevice(Current.settingsStore.currentRegistrationIdentity(for: server))
    }

    /// Whether `request` to `server` is held back: it reports this device, and the registration it would reach is
    /// another device's, so what it reports would land on that device until the user settles the registration.
    public func holdsBack(_ request: WebhookRequest, to server: Server) -> Bool {
        Self.reportingRequestTypes.contains(request.type) && isRegisteredByAnotherDevice(server)
    }

    /// Whether `identity` is another device's, so registering under it would take over that device's registration.
    /// Never on the Mac, nor while the device has no vendor identifier to compare.
    public func belongsToAnotherDevice(_ identity: RegistrationIdentity) -> Bool {
        guard !Current.isCatalyst, let vendorID = Current.device.identifierForVendor() else { return false }
        return identity.ownerVendorID != nil && identity.ownerVendorID != vendorID
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
        // Updates are held back while a registration is another device's, so this device's push token and sensors
        // only reach the servers now.
        servers.forEach(catchUp)
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
        // Registrations made with the default identifier are left to the device that shares it, so this device takes
        // a new default for whatever it registers with from here on.
        let leavesDefaultIdentifier = servers.contains {
            settings.currentRegistrationIdentity(for: $0).deviceID == settings.integrationDeviceID
        }
        recordIdentities()
        if leavesDefaultIdentifier || settings.integrationDeviceIDOwnerVendorID != vendorID {
            // Every registration has its identity recorded by now, so this changes none of them, only what this
            // device registers with from here on, such as a server it is added to later.
            settings.adoptNewIntegrationDeviceID(ownedBy: vendorID)
        }

        var failures = [Server: Error]()
        for server in servers {
            do {
                try await registerOnce(with: server, ownedBy: vendorID)
            } catch {
                Current.Log.error("failed to register with \(server.identifier) as a new device: \(error)")
                failures[server] = error
            }
        }
        return failures
    }

    /// Registers with `server` as a new device, or joins the attempt already under way with it, so the identity, the
    /// request and what the response is kept as happen once however many times it is asked for at the same time.
    private func registerOnce(with server: Server, ownedBy vendorID: String) async throws {
        let task = Self.inFlightLock.withLock { () -> Task<Void, Error> in
            if let running = Self.inFlight[server.identifier] {
                return running
            }
            let register = register
            let task = Task {
                Current.settingsStore.updateRegistrationRecord(for: server.identifier) { record in
                    // An earlier attempt's identity is reused: the server may have registered it before the
                    // response was lost, and registering it again replaces that registration rather than adding
                    // another.
                    guard record.pending?.ownerVendorID != vendorID else { return }
                    record.pending = RegistrationIdentity(
                        deviceID: Current.settingsStore.newIntegrationDeviceID(),
                        ownerVendorID: vendorID
                    )
                }
                try await register(server)
            }
            Self.inFlight[server.identifier] = task
            return task
        }
        defer {
            Self.inFlightLock.withLock {
                if Self.inFlight[server.identifier] == task {
                    Self.inFlight[server.identifier] = nil
                }
            }
        }
        try await task.value
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
        let name = try await unusedDeviceName(for: server, on: api)
        try await api.register(deviceName: name).asyncValue()

        // The new registration has none of the sensors the previous one had.
        SensorRegistrationVersionStore.forgetRegistration(for: server.identifier)
        do {
            try await api.Connect(reason: .warm).asyncValue(timeout: reconnectTimeout)
        } catch {
            // The registration is in place; whatever did not catch up is retried on the next connect.
            Current.Log.error("registered with \(server.identifier) as a new device, but failed to connect: \(error)")
        }
    }

    /// Brings the registration with `server` up to date with this device, as a connect does: its registration data,
    /// then its sensors. A failure is retried on the next connect.
    public static func catchUpWithServer(_ server: Server) {
        Current.api(for: server)?.Connect(reason: .warm).cauterize()
    }

    /// `name`, or the first of "`name` 2", "`name` 3" and on that no `mobile_app` device in `devices` has, other
    /// than the one registered as `deviceID`, which the registration replaces. Names are compared the way Home
    /// Assistant names notification actions after them, where "Phone 2" and "phone_2" are the same.
    static func unusedDeviceName(
        _ name: String,
        among devices: [DeviceRegistryEntry],
        replacing deviceID: String
    ) -> String {
        let taken = Set(devices.compactMap { device -> String? in
            let registrations = (device.identifiers ?? []).filter { $0.count == 2 && $0.first == "mobile_app" }
            guard !registrations.isEmpty, !registrations.contains(["mobile_app", deviceID]) else { return nil }
            return device.name.map(notificationName)
        })

        var candidate = name
        var number = 1
        while taken.contains(notificationName(candidate)) {
            number += 1
            candidate = "\(name) \(number)"
        }
        return candidate
    }

    /// The part of a notification action's name Home Assistant derives from a device `name`, as its `slugify` does:
    /// lowercased ASCII letters and digits, with other letters written in them, as "ø" is "o" and "ß" is "ss", a
    /// comma between digits dropped, as in "1,000", and everything else between them collapsed into single
    /// underscores.
    static func notificationName(_ name: String) -> String {
        let ascii = name.applyingTransform(StringTransform("Any-Latin; Latin-ASCII"), reverse: false) ?? name
        return ascii.lowercased()
            .replacingOccurrences(of: #"(?<=\d),(?=\d)"#, with: "", options: .regularExpression)
            .split { !($0.isASCII && ($0.isLetter || $0.isNumber)) }
            .joined(separator: "_")
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
            replacing: Current.settingsStore.registrationIdentity(for: server).deviceID
        )
    }

    /// Records the identity of each registration this installation has no record of, which until now follows
    /// `integrationDeviceID` and its owner, before either changes.
    private func recordIdentities() {
        let settings = Current.settingsStore
        for server in Current.servers.all {
            let identity = settings.currentRegistrationIdentity(for: server)
            settings.updateRegistrationRecord(for: server.identifier) { record in
                if record.current == nil {
                    record.current = identity
                }
            }
            // Kept with the server too, which outlives the record when the app is reinstalled.
            if server.info.setting(for: .registeredDeviceID) == nil {
                server.update { $0.setSetting(value: identity.deviceID, for: .registeredDeviceID) }
            }
        }
    }
}
