import Foundation

#if os(watchOS)
/// Reports the watch's own sensors to every server, registering the watch as a `mobile_app` device
/// of its own first.
///
/// Runs on the watch's schedule — foreground, the periodic background refresh, a settings change —
/// and talks to the server directly, so it doesn't need the paired iPhone to be reachable or even
/// running. Runs are coalesced: a trigger that lands while a run is in flight waits for it rather
/// than starting another, because two runs that both find no registration would each register,
/// and Home Assistant creates a new device for every registration request.
public actor WatchDeviceReporter {
    public static let shared = WatchDeviceReporter()

    /// Posted on the main queue once a run finishes, so an open settings screen refreshes its status.
    public static let didFinishNotification = Notification.Name("WatchDeviceReporterDidFinish")

    public enum Trigger: String {
        case foreground
        case backgroundRefresh
        case settingsChange
    }

    public enum Outcome: Equatable {
        /// The switched-on sensors were sent.
        case reported(sensorCount: Int)
        /// The watch is registered but no sensor is switched on, so there was nothing to send.
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

    /// The run in progress, if any. Actor isolation alone doesn't serialize runs — every network
    /// `await` lets another trigger in — so a new trigger joins this one instead.
    private var inFlight: Task<[Report], Never>?

    public init() {}

    /// Reports to every configured server and returns what happened for each. A trigger that
    /// arrives during a run waits for that run and then runs itself, so a settings change made
    /// mid-run still gets sent.
    @discardableResult
    public func report(trigger: Trigger) async -> [Report] {
        if let inFlight {
            Current.Log.verbose("watch sensor report (\(trigger.rawValue)) waiting for the run in flight")
            _ = await inFlight.value
        }

        let defaults = WatchUserDefaults.shared
        if trigger == .foreground,
           let lastSuccess = defaults.lastSensorReportAt,
           Current.date().timeIntervalSince(lastSuccess) < Self.minimumForegroundInterval {
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

        // Servers are independent, and the background budget is too short to take them in turn.
        let servers = Current.servers.all
        let reports = await withTaskGroup(of: (Int, Report).self) { group -> [Report] in
            for (index, server) in servers.enumerated() {
                group.addTask {
                    let outcome = await self.report(server: server, trigger: trigger)
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
        let defaults = WatchUserDefaults.shared
        if anyReported {
            defaults.lastSensorReportAt = Current.date()
        }
        defaults.lastSensorReportError = failures.first

        await MainActor.run {
            NotificationCenter.default.post(name: Self.didFinishNotification, object: nil)
        }

        return reports
    }

    private func report(server: Server, trigger: Trigger) async -> Outcome {
        guard server.activeURLUsingLastKnownNetworkState() != nil else {
            return .skipped(reason: "no active URL")
        }

        do {
            return try await report(server: server, timeout: Self.timeout(for: trigger), allowingReregistration: true)
        } catch {
            Current.Log.error("watch sensor report to \(server.info.name) failed: \(error)")
            return .failed("\(server.info.name): \(error.localizedDescription)")
        }
    }

    private func report(server: Server, timeout: TimeInterval, allowingReregistration: Bool) async throws -> Outcome {
        let store = Current.watchDeviceRegistrations
        let registration: WatchDeviceRegistration
        if let existing = store.registration(for: server.identifier) {
            registration = existing
        } else {
            registration = try await WatchDeviceRegistrar.register(server: server, timeout: timeout)
        }

        do {
            return try await sync(server: server, registration: registration, timeout: timeout)
        } catch WatchWebhookClient.WebhookError.registrationGone where allowingReregistration {
            // The device was deleted in Home Assistant: forget the registration and start over,
            // once — a second miss in the same run means something other than a stale registration.
            Current.Log.info("watch registration with \(server.info.name) is gone; registering again")
            try store.set(nil, for: server.identifier)
            return try await report(server: server, timeout: timeout, allowingReregistration: false)
        }
    }

    /// Registers whichever sensors Home Assistant doesn't know with their current enablement, then
    /// sends the switched-on ones.
    private func sync(
        server: Server,
        registration: WatchDeviceRegistration,
        timeout: TimeInterval
    ) async throws -> Outcome {
        let sensors = WatchDeviceSensors.current()
        let enabledIDs = WatchUserDefaults.shared.enabledSensorIDs

        let outdated = sensors.filter { sensor in
            guard let uniqueID = sensor.UniqueID else { return false }
            return registration.registeredSensorEnablement[uniqueID] != enabledIDs.contains(uniqueID)
        }
        try await register(
            sensors: outdated,
            enabledIDs: enabledIDs,
            server: server,
            registration: registration,
            timeout: timeout
        )

        guard sensors.contains(where: { sensor in sensor.UniqueID.map { enabledIDs.contains($0) } ?? false }) else {
            return .nothingEnabled
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

        return .reported(sensorCount: enabledIDs.intersection(sensors.compactMap(\.UniqueID)).count)
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
        let store = Current.watchDeviceRegistrations
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
        guard let registration = Current.watchDeviceRegistrations.registration(for: server.identifier) else {
            throw WatchWebhookClient.WebhookError.registrationGone
        }

        let response = try await WatchWebhookClient.send(
            type: type,
            data: data,
            server: server,
            registration: registration,
            timeout: timeout
        )

        // Home Assistant answers a deleted registration with 200 and no body (the cloudhook, with a
        // 404, which `WatchWebhookClient` already maps). Any other shape is a real answer.
        if response is Void {
            throw WatchWebhookClient.WebhookError.registrationGone
        }
        return response
    }
}
#endif
