import CoreLocation
import Foundation

/// Reports the watch's own sensors, and its location where the user chose to share it, to every
/// server, registering the watch as a `mobile_app` device of its own first.
///
/// Runs on the watch's schedule — foreground, the periodic background refresh, a settings change —
/// and talks to the server directly, so it doesn't need the paired iPhone to be reachable or even
/// running. Runs are coalesced: a trigger that lands while a run is in flight waits for it rather
/// than starting another, because two runs that both find no registration would each register,
/// and Home Assistant creates a new device for every registration request.
///
/// Everything it touches comes in through `Dependencies`, so the orchestration — first
/// registration, enablement changes, a deleted registration, per-server failures — is exercised by
/// unit tests on every platform, with the watch supplying the real pieces in `shared`.
public actor WatchDeviceReporter {
    /// What a run needs from the outside world.
    public struct Dependencies {
        public var settings: WatchSensorSettings
        public var registrations: WatchDeviceRegistrationStore
        public var servers: () -> [Server]
        /// Whether the server currently resolves to a URL the watch can reach.
        public var hasActiveURL: (Server) -> Bool
        public var currentSensors: () -> [WebhookSensor]
        /// What the watch registers as right now; a stored registration named otherwise is renamed.
        public var identity: (Server) -> WatchDeviceIdentity
        public var register: (Server, TimeInterval) async throws -> WatchDeviceRegistration
        public var send: (String, Any, Server, WatchDeviceRegistration, TimeInterval) async throws -> Any
        public var now: () -> Date
        /// What the server receives of the watch's location. `.never` sends nothing.
        public var locationPrivacy: (Server) -> ServerLocationPrivacy
        /// A fresh fix, or `nil` when one can't be had within the timeout (or isn't permitted).
        public var currentLocation: (TimeInterval) async -> CLLocation?
        /// Brings the watch's copy of a server's zones up to date, for zone-only reports, and says
        /// whether the watch has any. A server always has a home zone, so having none means they
        /// were never fetched.
        public var refreshZones: (Server, TimeInterval) async -> Bool
        /// The server's tracked zones a location falls in, smallest first.
        public var zonesContaining: (CLLocation, Server) -> [AppZone]
        /// Whether the server still holds a location the user has since stopped sharing with it.
        public var isLocationClearPending: (Server) -> Bool
        /// Records that the server no longer holds a location.
        public var locationCleared: (Server) -> Void

        public init(
            settings: WatchSensorSettings,
            registrations: WatchDeviceRegistrationStore,
            servers: @escaping () -> [Server],
            hasActiveURL: @escaping (Server) -> Bool,
            currentSensors: @escaping () -> [WebhookSensor],
            identity: @escaping (Server) -> WatchDeviceIdentity,
            register: @escaping (Server, TimeInterval) async throws -> WatchDeviceRegistration,
            send: @escaping (String, Any, Server, WatchDeviceRegistration, TimeInterval) async throws -> Any,
            now: @escaping () -> Date,
            locationPrivacy: @escaping (Server) -> ServerLocationPrivacy = { _ in .never },
            currentLocation: @escaping (TimeInterval) async -> CLLocation? = { _ in nil },
            refreshZones: @escaping (Server, TimeInterval) async -> Bool = { _, _ in true },
            zonesContaining: @escaping (CLLocation, Server) -> [AppZone] = { _, _ in [] },
            isLocationClearPending: @escaping (Server) -> Bool = { _ in false },
            locationCleared: @escaping (Server) -> Void = { _ in }
        ) {
            self.settings = settings
            self.registrations = registrations
            self.servers = servers
            self.hasActiveURL = hasActiveURL
            self.currentSensors = currentSensors
            self.identity = identity
            self.register = register
            self.send = send
            self.now = now
            self.locationPrivacy = locationPrivacy
            self.currentLocation = currentLocation
            self.refreshZones = refreshZones
            self.zonesContaining = zonesContaining
            self.isLocationClearPending = isLocationClearPending
            self.locationCleared = locationCleared
        }
    }

    #if os(watchOS)
    public static let shared = WatchDeviceReporter(dependencies: .live)
    #endif

    /// Posted on the main queue once a run finishes, so an open settings screen refreshes its status.
    public static let didFinishNotification = Notification.Name("WatchDeviceReporterDidFinish")

    public enum Trigger: String {
        case foreground
        case backgroundRefresh
        case settingsChange
    }

    public enum Outcome: Equatable {
        /// The switched-on sensors were sent, and the location when the server receives it.
        case reported(sensorCount: Int, locationSent: Bool = false)
        /// The watch is registered but neither a sensor nor its location is switched on for this
        /// server, so there was nothing to send.
        case nothingEnabled
        case skipped(reason: String)
        case failed(String)
    }

    public struct Report: Equatable {
        public let server: Identifier<Server>
        public let outcome: Outcome
    }

    /// A foreground run this soon after a successful one is skipped: opening the app a few times in
    /// a row shouldn't spend the watch's network budget on values that haven't moved.
    public static let minimumForegroundInterval: TimeInterval = 5 * 60

    /// Requests during the system's background refresh get a tighter deadline: its wall-clock budget
    /// is short (see `ExtensionDelegate.handle(_:)`), and a request that outlives it is wasted.
    static func timeout(for trigger: Trigger) -> TimeInterval {
        switch trigger {
        case .backgroundRefresh: return 8
        case .foreground, .settingsChange: return 20
        }
    }

    /// How long a run waits for a location fix. Kept short in the background refresh, whose budget
    /// also has to cover the requests.
    static func locationTimeout(for trigger: Trigger) -> TimeInterval {
        switch trigger {
        case .backgroundRefresh: return 5
        case .foreground: return 10
        case .settingsChange: return 15
        }
    }

    /// What the location report says caused it, as Home Assistant and the iPhone's history name it.
    static func locationTrigger(for trigger: Trigger) -> LocationUpdateTrigger {
        switch trigger {
        case .foreground: return .Launch
        case .backgroundRefresh: return .BackgroundFetch
        case .settingsChange: return .Manual
        }
    }

    private let dependencies: Dependencies

    /// What a run knows about where the watch is, shared by every server's report.
    private struct LocationContext {
        let fix: CLLocation?
        let trigger: LocationUpdateTrigger
    }

    /// The run in progress, if any. Actor isolation alone doesn't serialize runs — every network
    /// `await` lets another trigger in — so a new trigger joins this one instead.
    private var inFlight: Task<[Report], Never>?

    public init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    /// Reports to every configured server and returns what happened for each. A trigger that
    /// arrives during a run waits for that run and then runs itself, so a settings change made
    /// mid-run still gets sent.
    @discardableResult
    public func report(trigger: Trigger) async -> [Report] {
        if let inFlight {
            Current.Log.verbose("watch sensor report (\(trigger.rawValue)) waiting for the run in flight")
            _ = await inFlight.value
        }

        if trigger == .foreground,
           let lastSuccess = dependencies.settings.lastSensorReportAt,
           dependencies.now().timeIntervalSince(lastSuccess) < Self.minimumForegroundInterval {
            Current.Log.verbose("skipping watch sensor report on foreground; reported \(lastSuccess)")
            return []
        }

        let run = Task { await self.run(trigger: trigger) }
        inFlight = run
        let reports = await run.value
        if inFlight == run {
            inFlight = nil
        }
        return reports
    }

    private func run(trigger: Trigger) async -> [Report] {
        Current.Log.info("reporting watch sensors (\(trigger.rawValue))")

        let servers = dependencies.servers()

        // One fix serves every server, and is only taken when one the watch can reach receives it.
        let sharesLocation = servers.contains { server in
            dependencies.locationPrivacy(server) != .never && dependencies.hasActiveURL(server)
        }
        let fix = sharesLocation ? await dependencies.currentLocation(Self.locationTimeout(for: trigger)) : nil
        let location = LocationContext(fix: fix, trigger: Self.locationTrigger(for: trigger))

        // Servers are independent, and the background budget is too short to take them in turn.
        let reports = await withTaskGroup(of: (Int, Report).self) { group -> [Report] in
            for (index, server) in servers.enumerated() {
                group.addTask {
                    let outcome = await self.report(server: server, trigger: trigger, location: location)
                    Current.Log.info("watch sensor report to \(server.info.name): \(outcome)")
                    return (index, Report(server: server.identifier, outcome: outcome))
                }
            }
            var indexed = [(Int, Report)]()
            for await result in group {
                indexed.append(result)
            }
            return indexed.sorted { $0.0 < $1.0 }.map(\.1)
        }

        let failures = reports.compactMap { report -> String? in
            guard case let .failed(description) = report.outcome else { return nil }
            return description
        }
        let anyReported = reports.contains { report in
            if case .reported = report.outcome { return true }
            return false
        }
        if anyReported {
            dependencies.settings.lastSensorReportAt = dependencies.now()
        }
        dependencies.settings.lastSensorReportError = failures.first

        await MainActor.run {
            NotificationCenter.default.post(name: Self.didFinishNotification, object: nil)
        }

        return reports
    }

    private func report(server: Server, trigger: Trigger, location: LocationContext) async -> Outcome {
        guard dependencies.hasActiveURL(server) else {
            return .skipped(reason: "no active URL")
        }

        do {
            return try await report(
                server: server,
                timeout: Self.timeout(for: trigger),
                location: location,
                allowingReregistration: true
            )
        } catch {
            Current.Log.error("watch sensor report to \(server.info.name) failed: \(error)")
            return .failed("\(server.info.name): \(error.localizedDescription)")
        }
    }

    private func report(
        server: Server,
        timeout: TimeInterval,
        location: LocationContext,
        allowingReregistration: Bool
    ) async throws -> Outcome {
        let store = dependencies.registrations

        do {
            let registration: WatchDeviceRegistration
            if let existing = store.registration(for: server.identifier) {
                registration = try await renamedIfNeeded(existing, server: server, timeout: timeout)
            } else {
                registration = try await dependencies.register(server, timeout)
            }
            let sensorCount = try await sync(server: server, registration: registration, timeout: timeout)
            let locationSent = try await sendLocation(server: server, location: location, timeout: timeout)
            switch (sensorCount, locationSent) {
            case (.none, false) where dependencies.locationPrivacy(server) != .never:
                return .skipped(reason: "no location to send")
            case (.none, false):
                return .nothingEnabled
            case let (count, sent):
                return .reported(sensorCount: count ?? 0, locationSent: sent)
            }
        } catch WatchWebhookClient.WebhookError.registrationGone where allowingReregistration {
            // The device was deleted in Home Assistant: forget the registration and start over,
            // once — a second miss in the same run means something other than a stale registration.
            Current.Log.info("watch registration with \(server.info.name) is gone; registering again")
            try store.set(nil, for: server.identifier)
            return try await report(server: server, timeout: timeout, location: location, allowingReregistration: false)
        }
    }

    /// Sends `update_registration` when the device name changed since the registration was made.
    private func renamedIfNeeded(
        _ registration: WatchDeviceRegistration,
        server: Server,
        timeout: TimeInterval
    ) async throws -> WatchDeviceRegistration {
        let identity = dependencies.identity(server)
        guard !WatchDeviceIdentity.isDeviceName(registration.deviceName, variantOf: identity.deviceName) else {
            return registration
        }

        Current.Log.info("renaming watch registration with \(server.info.name) to \"\(identity.deviceName)\"")
        _ = try await send(
            type: "update_registration",
            data: WatchDeviceRegistrar.updateRegistrationBody(identity: identity),
            server: server,
            timeout: timeout
        )

        var renamed = dependencies.registrations.registration(for: server.identifier) ?? registration
        renamed.deviceName = identity.deviceName
        try dependencies.registrations.set(renamed, for: server.identifier)
        return renamed
    }

    /// Registers whichever sensors Home Assistant doesn't know with their current enablement, then
    /// sends the switched-on ones. Sensors are chosen per server, so what this server receives is
    /// its own selection and nothing another server was switched on for. Returns how many were
    /// sent, or `nil` when none is switched on.
    private func sync(
        server: Server,
        registration: WatchDeviceRegistration,
        timeout: TimeInterval
    ) async throws -> Int? {
        let sensors = dependencies.currentSensors()
        let enabledIDs = dependencies.settings.enabledSensorIDs(forServer: server.identifier)

        let describesAnotherVersion = registration.registeredAppVersion != AppConstants.version

        let outdated = sensors.filter { sensor in
            guard let uniqueID = sensor.UniqueID else { return false }
            guard !describesAnotherVersion else { return true }
            return registration.registeredSensorEnablement[uniqueID] != enabledIDs.contains(uniqueID)
        }
        try await register(
            sensors: outdated,
            enabledIDs: enabledIDs,
            server: server,
            registration: registration,
            timeout: timeout
        )

        if describesAnotherVersion {
            var updated = dependencies.registrations.registration(for: server.identifier) ?? registration
            updated.registeredAppVersion = AppConstants.version
            try dependencies.registrations.set(updated, for: server.identifier)
        }

        guard sensors.contains(where: { sensor in sensor.UniqueID.map { enabledIDs.contains($0) } ?? false }) else {
            return nil
        }

        let payload = WatchDeviceSensors.updatePayload(sensors: sensors, enabledIDs: enabledIDs)
        var response = try await send(type: "update_sensor_states", data: payload, server: server, timeout: timeout)

        // Home Assistant answers per sensor; one it doesn't know needs registering, after which the
        // same values are sent once more so this run doesn't leave that sensor a cycle behind.
        let unregistered = WatchDeviceSensors.unregisteredIDs(in: response)
        if !unregistered.isEmpty {
            Current.Log.info("\(server.info.name) doesn't know watch sensors \(unregistered); registering")
            try await register(
                sensors: sensors.filter { sensor in sensor.UniqueID.map { unregistered.contains($0) } ?? false },
                enabledIDs: enabledIDs,
                server: server,
                registration: registration,
                timeout: timeout
            )
            response = try await send(type: "update_sensor_states", data: payload, server: server, timeout: timeout)
        }

        // Anything still rejected inside the successful response is a failure of this run, not a
        // value Home Assistant took.
        let rejections = WatchDeviceSensors.rejections(in: response)
        if !rejections.isEmpty {
            let description = rejections.sorted { $0.key < $1.key }
                .map { "\($0.key): \($0.value)" }
                .joined(separator: ", ")
            throw WatchDeviceReporterError.sensorsRejected(description)
        }

        return enabledIDs.intersection(sensors.compactMap(\.UniqueID)).count
    }

    /// Sends `update_location` with what the server's privacy choice allows, which is what feeds
    /// the watch's own device tracker. Returns whether anything was sent: nothing is when the
    /// server receives no location, or when the run has no fix (or, for zone-only, no zones).
    private func sendLocation(server: Server, location: LocationContext, timeout: TimeInterval) async throws -> Bool {
        let privacy = dependencies.locationPrivacy(server)
        guard privacy != .never else {
            return try await clearLocationIfPending(server: server, trigger: location.trigger, timeout: timeout)
        }

        guard let fix = location.fix else {
            Current.Log.info("no location fix to send to \(server.info.name) from the watch")
            return false
        }

        // Zone-only reports are worked out against the server's zones. Without them every report
        // would say the watch is away, so none is sent until they arrive.
        if privacy == .zoneOnly {
            let hasZones = await dependencies.refreshZones(server, timeout)
            guard hasZones else {
                Current.Log.info("no zones for \(server.info.name) on the watch yet; not sending its zone")
                return false
            }
        }

        let update = WebhookUpdateLocation(
            privacy: privacy,
            trigger: location.trigger,
            location: fix,
            zone: nil,
            supportsInZones: server.info.version >= .inZonesOnLocationUpdate,
            currentSSID: nil,
            zonesContaining: { [dependencies] in dependencies.zonesContaining($0, server) }
        )
        _ = try await send(type: "update_location", data: update.toJSON(), server: server, timeout: timeout)
        return true
    }

    /// Home Assistant keeps the last location it was sent until it gets another one, so a server
    /// the user stopped sharing with would go on showing where the watch was. One update with no
    /// location in it replaces that, as the iPhone's own updates do once it is set to never.
    private func clearLocationIfPending(
        server: Server,
        trigger: LocationUpdateTrigger,
        timeout: TimeInterval
    ) async throws -> Bool {
        guard dependencies.isLocationClearPending(server) else { return false }

        let payload = WebhookUpdateLocation(trigger: trigger).toJSON()
        _ = try await send(type: "update_location", data: payload, server: server, timeout: timeout)
        dependencies.locationCleared(server)
        return true
    }

    private func register(
        sensors: [WebhookSensor],
        enabledIDs: Set<String>,
        server: Server,
        registration: WatchDeviceRegistration,
        timeout: TimeInterval
    ) async throws {
        guard !sensors.isEmpty else { return }

        // Re-read rather than mutate the caller's copy: each successful registration is written back
        // right away, so a failure part-way through keeps what did get through.
        let store = dependencies.registrations
        for sensor in sensors {
            guard let uniqueID = sensor.UniqueID else { continue }
            let enabled = enabledIDs.contains(uniqueID)
            let payload = WatchDeviceSensors.registrationPayload(sensor: sensor, enabled: enabled)
            _ = try await send(type: "register_sensor", data: payload, server: server, timeout: timeout)

            var updated = store.registration(for: server.identifier) ?? registration
            updated.registeredSensorEnablement[uniqueID] = enabled
            try store.set(updated, for: server.identifier)
        }
    }

    /// Sends through the stored registration, reading it fresh so a re-registration earlier in the
    /// run is what gets used. An empty body means Home Assistant no longer knows the webhook.
    private func send(type: String, data: Any, server: Server, timeout: TimeInterval) async throws -> Any {
        guard let registration = dependencies.registrations.registration(for: server.identifier) else {
            throw WatchWebhookClient.WebhookError.registrationGone
        }

        let response = try await dependencies.send(type, data, server, registration, timeout)

        // Home Assistant answers a deleted registration with 200 and no body (the cloudhook, with a
        // 404, which `WatchWebhookClient` already maps). Any other shape is a real answer.
        if response is Void {
            throw WatchWebhookClient.WebhookError.registrationGone
        }
        return response
    }
}

#if os(watchOS)
public extension WatchDeviceReporter.Dependencies {
    /// The real watch: its settings, Keychain, servers, sensors and network.
    static var live: WatchDeviceReporter.Dependencies {
        WatchDeviceReporter.Dependencies(
            settings: WatchUserDefaults.shared,
            registrations: Current.watchDeviceRegistrations,
            servers: { Current.servers.all },
            hasActiveURL: { server in server.activeURLUsingLastKnownNetworkState() != nil },
            currentSensors: WatchDeviceSensors.current,
            identity: { server in .current(for: server) },
            register: { server, timeout in
                try await WatchDeviceRegistrar.register(server: server, timeout: timeout)
            },
            send: { type, data, server, registration, timeout in
                try await WatchWebhookClient.send(
                    type: type,
                    data: data,
                    server: server,
                    registration: registration,
                    timeout: timeout
                )
            },
            now: Current.date,
            locationPrivacy: { server in WatchUserDefaults.shared.locationPrivacy(forServer: server.identifier) },
            currentLocation: { timeout in
                // Never prompts: permission is asked for when the user picks what to share.
                switch Current.location.permissionStatus() {
                case .authorizedAlways, .authorizedWhenInUse:
                    break
                default:
                    Current.Log.info("watch location not authorized; reporting without a fix")
                    return nil
                }
                do {
                    return try await CLLocationManager.oneShotLocation(timeout: timeout).asyncValue()
                } catch {
                    Current.Log.info("watch location fix failed: \(error)")
                    return nil
                }
            },
            refreshZones: { server, timeout in
                do {
                    try await WatchZoneSync.refreshIfNeeded(server: server, timeout: timeout)
                } catch {
                    // Zones already stored are still used; the next run tries again.
                    Current.Log.error("failed refreshing zones for \(server.info.name) on the watch: \(error)")
                }
                return AppZone.all().contains { $0.serverIdentifier == server.identifier.rawValue }
            },
            zonesContaining: { location, server in AppZone.zones(of: location, in: server) },
            isLocationClearPending: { server in
                WatchUserDefaults.shared.isLocationClearPending(forServer: server.identifier)
            },
            locationCleared: { server in
                WatchUserDefaults.shared.setLocationClearPending(false, forServer: server.identifier)
            }
        )
    }
}
#endif
