import Foundation
import HAKit
import HAKit_PromiseKit
import PromiseKit
import UserNotifications

/// Settles the registrations a device carries from a backup of another device: each belongs to the device whose
/// vendor identifier it was made with, and the user either keeps them or registers anew.
public struct RegistrationOwnership {
    public typealias Register = (Server) async throws -> Void
    public typealias CatchUp = (Server) -> Void
    public typealias Notify = (Server) -> Void
    static let reportingRequestTypes: Set<String> = ["update_location", "update_sensor_states", "register_sensor"]
    public static let didSettleRegistration = Notification.Name("RegistrationOwnership.didSettleRegistration")

    static let deviceListTimeout: TimeInterval = 30
    /// Non-private for tests.
    static var reconnectTimeout: TimeInterval = 30

    /// The servers whose held back reports were already told about, each with the other device it was for.
    static let heldBackNotifiedKey = "registrationHeldBackNotified"
    private static let heldBackNotifiedLock = NSLock()

    static let earlierRegistrationsAdoptedKey = "registrationOwnershipAdoptedEarlierRegistrations"
    private static let adoptionLock = NSLock()

    private static let inFlightLock = NSLock()
    private static var inFlight = [Identifier<Server>: Task<Void, Error>]()

    private let register: Register
    private let catchUp: CatchUp
    private let notify: Notify

    public init(
        register: @escaping Register = RegistrationOwnership.registerWithServer(_:),
        catchUp: @escaping CatchUp = RegistrationOwnership.catchUpWithServer(_:),
        notify: @escaping Notify = RegistrationOwnership.notifyHeldBack(_:)
    ) {
        self.register = register
        self.catchUp = catchUp
        self.notify = notify
        Self.adoptEarlierRegistrations()
    }

    public func serversRegisteredByAnotherDevice() -> [Server] {
        Self.adoptEarlierRegistrations()
        return Current.servers.all.filter(isRegisteredByAnotherDevice)
    }

    public func isRegisteredByAnotherDevice(_ server: Server) -> Bool {
        Self.adoptEarlierRegistrations()
        return !server.info.requiresReauthenticationAfterMirrorRestore
            && belongsToAnotherDevice(Current.settingsStore.currentRegistrationIdentity(for: server))
    }

    public func holdsBack(_ request: WebhookRequest, to server: Server) -> Bool {
        Self.reportingRequestTypes.contains(request.type) && isRegisteredByAnotherDevice(server)
    }

    /// Reports stay held back until the person chooses, which nobody notices from a background launch, so the first
    /// time they are for a given other device, a notification says so. Opening the app asks what to do; while it is
    /// in the foreground it asks anyway, so nothing is sent then and the next background launch still notifies.
    public func noteHeldBack(by server: Server) {
        DispatchQueue.main.async { [self] in
            #if os(iOS)
            guard !Current.isForegroundApp() else { return }
            #endif
            guard let owner = Current.settingsStore.currentRegistrationIdentity(for: server).ownerVendorID else {
                return
            }
            let mark = "\(server.identifier.rawValue) \(owner)"
            let prefs = Current.settingsStore.prefs
            let isFirst = Self.heldBackNotifiedLock.withLock { () -> Bool in
                var marks = prefs.stringArray(forKey: Self.heldBackNotifiedKey) ?? []
                guard !marks.contains(mark) else { return false }
                marks.append(mark)
                prefs.set(marks, forKey: Self.heldBackNotifiedKey)
                return true
            }
            guard isFirst else { return }
            Current.Log.info("telling the person reports to \(server.identifier) are held back")
            notify(server)
        }
    }

    public static func notifyHeldBack(_ server: Server) {
        guard !Current.isRunningTests else { return }
        let content = UNMutableNotificationContent()
        content.title = L10n.RestoredRegistrations.HeldBackNotification.title
        content.body = L10n.RestoredRegistrations.HeldBackNotification.body(server.info.name)
        let request = UNNotificationRequest(
            identifier: "registration-held-back-\(server.identifier.rawValue)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                Current.Log.error("failed to tell the person reports to \(server.identifier) are held back: \(error)")
            }
        }
    }

    public func belongsToAnotherDevice(_ identity: RegistrationIdentity) -> Bool {
        guard !Current.isCatalyst, let vendorID = Current.device.identifierForVendor() else { return false }
        Self.adoptEarlierRegistrations()
        return identity.ownerVendorID != nil && identity.ownerVendorID != vendorID
    }

    /// Whoever moved devices before ownership was recorded already settled it, so only later restores ask.
    static func adoptEarlierRegistrations() {
        guard !Current.isCatalyst, let vendorID = Current.device.identifierForVendor() else { return }
        let settings = Current.settingsStore
        adoptionLock.withLock {
            guard !settings.prefs.bool(forKey: earlierRegistrationsAdoptedKey) else { return }
            var adopted = [Identifier<Server>]()
            let unrecorded = Current.servers.all
                .filter { settings.registrationRecord(for: $0.identifier).current == nil }
            for server in unrecorded {
                let deviceID = settings.currentRegistrationIdentity(for: server).deviceID
                settings.updateRegistrationRecord(for: server.identifier) { record in
                    record.current = RegistrationIdentity(deviceID: deviceID, ownerVendorID: vendorID)
                }
                adopted.append(server.identifier)
            }
            settings.prefs.set(true, forKey: earlierRegistrationsAdoptedKey)
            Current.Log.info("took the registrations of \(adopted) made before ownership was recorded as this device's")
        }
    }

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
        servers.forEach(catchUp)
        for server in servers {
            NotificationCenter.default.post(name: Self.didSettleRegistration, object: server.identifier)
        }
    }

    public func registerAsNewDevice(_ servers: [Server]) async -> [Server: Error] {
        guard let vendorID = Current.device.identifierForVendor() else {
            return Dictionary(uniqueKeysWithValues: servers.map {
                ($0, RegistrationOwnershipError.noDeviceIdentifier as Error)
            })
        }

        let settings = Current.settingsStore
        let leavesDefaultIdentifier = servers.contains {
            settings.currentRegistrationIdentity(for: $0).deviceID == settings.integrationDeviceID
        }
        recordIdentities()
        if leavesDefaultIdentifier || settings.integrationDeviceIDOwnerVendorID != vendorID {
            settings.adoptNewIntegrationDeviceID(ownedBy: vendorID)
        }

        var failures = [Server: Error]()
        for server in servers {
            do {
                try await registerOnce(with: server, ownedBy: vendorID)
                NotificationCenter.default.post(name: Self.didSettleRegistration, object: server.identifier)
            } catch {
                Current.Log.error("failed to register with \(server.identifier) as a new device: \(error)")
                failures[server] = error
            }
        }
        return failures
    }

    private func registerOnce(with server: Server, ownedBy vendorID: String) async throws {
        let task = Self.inFlightLock.withLock { () -> Task<Void, Error> in
            if let running = Self.inFlight[server.identifier] {
                return running
            }
            let register = register
            let task = Task {
                Current.settingsStore.updateRegistrationRecord(for: server.identifier) { record in
                    // Reused across attempts: the server may have registered it before the response was lost.
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

    @MainActor
    public static func registerWithServer(_ server: Server) async throws {
        guard let api = Current.api(for: server) else {
            throw ServerConnectionError.noActiveURL(server.info.name)
        }

        // Notification actions are named after devices, so the name must be unique on the server.
        let name = try await unusedDeviceName(for: server, on: api)
        try await api.register(deviceName: name).asyncValue()

        SensorRegistrationVersionStore.forgetRegistration(for: server.identifier)
        do {
            try await api.Connect(reason: .warm).asyncValue(timeout: reconnectTimeout)
        } catch {
            Current.Log.error("registered with \(server.identifier) as a new device, but failed to connect: \(error)")
        }
    }

    public static func catchUpWithServer(_ server: Server) {
        Current.api(for: server)?.Connect(reason: .warm).cauterize()
    }

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

        var base = name
        if let stripped = nameBeforeNumber(name), taken.contains(notificationName(stripped)) {
            base = stripped
        }

        var candidate = name
        var number = 1
        while taken.contains(notificationName(candidate)) {
            number += 1
            candidate = "\(base) \(number)"
        }
        return candidate
    }

    private static func nameBeforeNumber(_ name: String) -> String? {
        let parts = name.split(separator: " ", omittingEmptySubsequences: false)
        guard parts.count > 1, let last = parts.last, !last.isEmpty, last.allSatisfy(\.isNumber) else { return nil }
        return parts.dropLast().joined(separator: " ")
    }

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
