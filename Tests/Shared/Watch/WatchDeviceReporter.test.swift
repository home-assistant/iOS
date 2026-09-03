import Foundation
@testable import Shared
import Testing

/// Records what a run asked of its fakes, from whichever task the reporter calls them on.
private final class ReporterCallLog {
    private let lock = NSLock()
    private var registrations = 0
    private var sent = [(type: String, data: Any)]()

    var registerCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return registrations
    }

    var sends: [(type: String, data: Any)] {
        lock.lock()
        defer { lock.unlock() }
        return sent
    }

    func recordRegistration() {
        lock.lock()
        defer { lock.unlock() }
        registrations += 1
    }

    func record(type: String, data: Any) {
        lock.lock()
        defer { lock.unlock() }
        sent.append((type, data))
    }
}

// Serialized: the suites share `Current`, and the coalescing test measures timing.
@Suite(.serialized)
struct WatchDeviceReporterTests {
    private let server = Server.fake()
    private let store = FakeWatchDeviceRegistrationStore()
    private let settings = InMemoryWatchSensorSettings()
    private let log = ReporterCallLog()
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private let identity = WatchDeviceIdentity(
        appID: "io.robbie.HomeAssistant.watchkitapp",
        appName: "Home Assistant Watch",
        appVersion: "2026.1 (1)",
        deviceName: "Bruno's iPhone Apple Watch",
        deviceID: "watch-device-id",
        model: "Watch7,1",
        osName: "watchOS",
        osVersion: "26.0"
    )

    /// A registration made under `identity`, so nothing about it needs renaming.
    private var registration: WatchDeviceRegistration {
        WatchDeviceRegistration(
            webhookID: "watch-hook",
            webhookSecret: nil,
            cloudhookURL: nil,
            registeredAt: now,
            deviceName: identity.deviceName
        )
    }

    private var sensors: [WebhookSensor] {
        BatterySensor.sensors(battery: DeviceBattery(level: 80, state: .charging, attributes: [:]))
    }

    private static let accepted: [String: Any] = [
        "battery_level": ["success": true],
        "battery_state": ["success": true],
    ]

    /// A reporter whose `send` answers with `responses` in order, repeating the last one.
    private func reporter(
        hasActiveURL: Bool = true,
        responses: [Any],
        registerDelay: TimeInterval = 0
    ) -> WatchDeviceReporter {
        let lock = NSLock()
        var remaining = responses
        return WatchDeviceReporter(dependencies: .init(
            settings: settings,
            registrations: store,
            servers: { [server] },
            hasActiveURL: { _ in hasActiveURL },
            currentSensors: { sensors },
            identity: { _ in identity },
            register: { server, _ in
                log.recordRegistration()
                if registerDelay > 0 {
                    try await Task.sleep(nanoseconds: UInt64(registerDelay * 1_000_000_000))
                }
                try store.set(registration, for: server.identifier)
                return registration
            },
            send: { type, data, _, _, _ in
                log.record(type: type, data: data)
                lock.lock()
                defer { lock.unlock() }
                let response = remaining.first ?? ()
                if remaining.count > 1 { remaining.removeFirst() }
                return response
            },
            now: { now }
        ))
    }

    @Test func firstRunRegistersTheDeviceAndItsSensorsSwitchedOff() async throws {
        let reporter = reporter(responses: [["success": true]])

        let reports = await reporter.report(trigger: .settingsChange)

        #expect(reports == [.init(server: server.identifier, outcome: .nothingEnabled)])
        #expect(log.registerCount == 1)
        // Both sensors registered, disabled and without a value; nothing else sent.
        let sends = log.sends
        #expect(sends.map(\.type) == ["register_sensor", "register_sensor"])
        let payloads = sends.compactMap { $0.data as? [String: Any] }
        #expect(payloads.map { $0["unique_id"] as? String } == ["battery_level", "battery_state"])
        #expect(payloads.allSatisfy { $0["disabled"] as? Bool == true })
        #expect(payloads.allSatisfy { $0["state"] as? String == "unavailable" })
        let stored = try #require(store.registration(for: server.identifier))
        #expect(stored.registeredSensorEnablement == ["battery_level": false, "battery_state": false])
        #expect(settings.lastSensorReportAt == nil)
        #expect(settings.lastSensorReportError == nil)
    }

    @Test func sendsTheSensorsSwitchedOn() async throws {
        settings.enabledSensorIDs = ["battery_level"]
        let reporter = reporter(responses: [["success": true], ["success": true], Self.accepted])

        let reports = await reporter.report(trigger: .backgroundRefresh)

        #expect(reports == [.init(server: server.identifier, outcome: .reported(sensorCount: 1))])
        let sends = log.sends
        #expect(sends.map(\.type) == ["register_sensor", "register_sensor", "update_sensor_states"])
        let update = try #require(sends.last?.data as? [[String: Any]])
        let level = try #require(update.first { $0["unique_id"] as? String == "battery_level" })
        #expect(level["state"] as? Int == 80)
        let state = try #require(update.first { $0["unique_id"] as? String == "battery_state" })
        #expect(state["state"] as? String == "unavailable")
        #expect(settings.lastSensorReportAt == now)
        #expect(settings.lastSensorReportError == nil)
    }

    @Test func registersOnlyTheSensorWhoseSwitchChanged() async throws {
        var known = registration
        known.registeredSensorEnablement = ["battery_level": false, "battery_state": false]
        try store.set(known, for: server.identifier)
        settings.enabledSensorIDs = ["battery_state"]
        let reporter = reporter(responses: [["success": true], Self.accepted])

        let reports = await reporter.report(trigger: .settingsChange)

        #expect(reports.first?.outcome == .reported(sensorCount: 1))
        #expect(log.registerCount == 0)
        let sends = log.sends
        #expect(sends.map(\.type) == ["register_sensor", "update_sensor_states"])
        let registered = try #require(sends.first?.data as? [String: Any])
        #expect(registered["unique_id"] as? String == "battery_state")
        #expect(registered["disabled"] as? Bool == false)
        #expect(store.registration(for: server.identifier)?.registeredSensorEnablement["battery_state"] == true)
    }

    @Test func registersAgainOnceWhenTheServerForgotTheDevice() async throws {
        var known = registration
        known.registeredSensorEnablement = ["battery_level": true, "battery_state": false]
        try store.set(known, for: server.identifier)
        settings.enabledSensorIDs = ["battery_level"]
        // Empty body: Home Assistant's answer for a webhook it no longer knows. Then, after the new
        // registration, both sensors register and the update is accepted.
        let reporter = reporter(responses: [(), ["success": true], ["success": true], Self.accepted])

        let reports = await reporter.report(trigger: .settingsChange)

        #expect(reports.first?.outcome == .reported(sensorCount: 1))
        #expect(log.registerCount == 1)
        #expect(log.sends.map(\.type) == [
            "update_sensor_states",
            "register_sensor",
            "register_sensor",
            "update_sensor_states",
        ])
        // The fresh registration starts without sensor enablement and learns it again.
        #expect(store.registration(for: server.identifier)?.registeredSensorEnablement == [
            "battery_level": true,
            "battery_state": false,
        ])
    }

    @Test func registersASensorTheServerDoesNotKnowAndResends() async throws {
        var known = registration
        known.registeredSensorEnablement = ["battery_level": true, "battery_state": false]
        try store.set(known, for: server.identifier)
        settings.enabledSensorIDs = ["battery_level"]
        let notRegistered: [String: Any] = [
            "battery_level": ["success": false, "error": ["code": "not_registered", "message": "unknown"]],
            "battery_state": ["success": true],
        ]
        let reporter = reporter(responses: [notRegistered, ["success": true], Self.accepted])

        let reports = await reporter.report(trigger: .backgroundRefresh)

        #expect(reports.first?.outcome == .reported(sensorCount: 1))
        #expect(log.sends.map(\.type) == ["update_sensor_states", "register_sensor", "update_sensor_states"])
        #expect((log.sends[1].data as? [String: Any])?["unique_id"] as? String == "battery_level")
    }

    @Test func aRejectedValueFailsTheRun() async throws {
        var known = registration
        known.registeredSensorEnablement = ["battery_level": true, "battery_state": false]
        try store.set(known, for: server.identifier)
        settings.enabledSensorIDs = ["battery_level"]
        let rejected: [String: Any] = [
            "battery_level": ["success": false, "error": ["code": "invalid_format", "message": "Bad value"]],
            "battery_state": ["success": true],
        ]
        let reporter = reporter(responses: [rejected])

        let reports = await reporter.report(trigger: .backgroundRefresh)

        guard case let .failed(description)? = reports.first?.outcome else {
            Issue.record("expected a failure, got \(String(describing: reports.first?.outcome))")
            return
        }
        #expect(description.contains(server.info.name))
        #expect(description.contains("battery_level: Bad value"))
        #expect(settings.lastSensorReportError == description)
        #expect(settings.lastSensorReportAt == nil)
    }

    @Test func aFailedRegistrationIsReportedNotRetried() async {
        store.writeError = CocoaError(.fileWriteUnknown)
        let reporter = reporter(responses: [["success": true]])

        let reports = await reporter.report(trigger: .settingsChange)

        guard case let .failed(description)? = reports.first?.outcome else {
            Issue.record("expected a failure, got \(String(describing: reports.first?.outcome))")
            return
        }
        #expect(description.contains(server.info.name))
        #expect(log.registerCount == 1)
        #expect(log.sends.isEmpty)
        #expect(settings.lastSensorReportError == description)
    }

    @Test func renamesARegistrationWhoseDeviceNameMoved() async throws {
        var known = registration
        known.deviceName = "Apple Watch"
        known.registeredSensorEnablement = ["battery_level": true, "battery_state": false]
        try store.set(known, for: server.identifier)
        settings.enabledSensorIDs = ["battery_level"]
        let reporter = reporter(responses: [["device_name": identity.deviceName], Self.accepted])

        let reports = await reporter.report(trigger: .backgroundRefresh)

        #expect(reports.first?.outcome == .reported(sensorCount: 1))
        #expect(log.registerCount == 0)
        let sends = log.sends
        #expect(sends.map(\.type) == ["update_registration", "update_sensor_states"])
        let update = try #require(sends.first?.data as? [String: Any])
        #expect(update["device_name"] as? String == "Bruno's iPhone Apple Watch")
        #expect(update["app_version"] as? String == "2026.1 (1)")
        #expect(update["model"] as? String == "Watch7,1")
        let stored = try #require(store.registration(for: server.identifier))
        #expect(stored.deviceName == "Bruno's iPhone Apple Watch")
        #expect(stored.webhookID == "watch-hook")
        #expect(stored.registeredSensorEnablement == ["battery_level": true, "battery_state": false])
    }

    @Test func renamesARegistrationMadeBeforeTheNameWasTracked() async throws {
        var known = registration
        known.deviceName = nil
        known.registeredSensorEnablement = ["battery_level": false, "battery_state": false]
        try store.set(known, for: server.identifier)
        let reporter = reporter(responses: [["device_name": identity.deviceName]])

        let reports = await reporter.report(trigger: .settingsChange)

        #expect(reports.first?.outcome == .nothingEnabled)
        #expect(log.sends.map(\.type) == ["update_registration"])
        #expect(store.registration(for: server.identifier)?.deviceName == "Bruno's iPhone Apple Watch")
    }

    @Test func aRegistrationWithTheRightNameIsNotRenamed() async throws {
        var known = registration
        known.registeredSensorEnablement = ["battery_level": false, "battery_state": false]
        try store.set(known, for: server.identifier)
        let reporter = reporter(responses: [])

        let reports = await reporter.report(trigger: .settingsChange)

        #expect(reports.first?.outcome == .nothingEnabled)
        #expect(log.sends.isEmpty)
    }

    @Test func aRenameTheServerNoLongerKnowsRegistersAgain() async throws {
        var known = registration
        known.deviceName = "Apple Watch"
        try store.set(known, for: server.identifier)
        // Empty body to the rename: the device was deleted in Home Assistant. The new registration
        // then registers both sensors.
        let reporter = reporter(responses: [(), ["success": true], ["success": true]])

        let reports = await reporter.report(trigger: .settingsChange)

        #expect(reports.first?.outcome == .nothingEnabled)
        #expect(log.registerCount == 1)
        #expect(log.sends.map(\.type) == ["update_registration", "register_sensor", "register_sensor"])
        #expect(store.registration(for: server.identifier)?.deviceName == "Bruno's iPhone Apple Watch")
    }

    @Test func aFailedRenameFailsTheRun() async throws {
        var known = registration
        known.deviceName = "Apple Watch"
        try store.set(known, for: server.identifier)
        store.writeError = CocoaError(.fileWriteUnknown)
        let reporter = reporter(responses: [["device_name": identity.deviceName]])

        let reports = await reporter.report(trigger: .settingsChange)

        guard case .failed? = reports.first?.outcome else {
            Issue.record("expected a failure, got \(String(describing: reports.first?.outcome))")
            return
        }
        #expect(log.sends.map(\.type) == ["update_registration"])
        // The rename wasn't kept, so it is sent again next run rather than lost.
        #expect(store.registration(for: server.identifier)?.deviceName == "Apple Watch")
    }

    @Test func skipsAServerWithoutAURL() async {
        let reporter = reporter(hasActiveURL: false, responses: [])

        let reports = await reporter.report(trigger: .backgroundRefresh)

        #expect(reports == [.init(server: server.identifier, outcome: .skipped(reason: "no active URL"))])
        #expect(log.registerCount == 0)
        #expect(log.sends.isEmpty)
    }

    @Test func foregroundIsThrottledAfterARecentSuccess() async {
        settings.lastSensorReportAt = now.addingTimeInterval(-60)
        let reporter = reporter(responses: [])

        let reports = await reporter.report(trigger: .foreground)

        #expect(reports.isEmpty)
        #expect(log.registerCount == 0)
    }

    @Test func foregroundRunsAgainOnceTheIntervalHasPassed() async {
        settings.lastSensorReportAt = now.addingTimeInterval(-WatchDeviceReporter.minimumForegroundInterval)
        let reporter = reporter(responses: [["success": true]])

        let reports = await reporter.report(trigger: .foreground)

        #expect(reports.count == 1)
        #expect(log.registerCount == 1)
    }

    @Test func overlappingTriggersRegisterOnce() async {
        settings.enabledSensorIDs = ["battery_level"]
        let reporter = reporter(responses: [["success": true], ["success": true], Self.accepted], registerDelay: 0.2)

        async let first = reporter.report(trigger: .backgroundRefresh)
        try? await Task.sleep(nanoseconds: 50_000_000)
        async let second = reporter.report(trigger: .settingsChange)
        let (firstReports, secondReports) = await (first, second)

        // The second trigger waited for the first run and then ran itself against the registration
        // it left behind, so the device was registered exactly once.
        #expect(log.registerCount == 1)
        #expect(firstReports.first?.outcome == .reported(sensorCount: 1))
        #expect(secondReports.first?.outcome == .reported(sensorCount: 1))
    }

    @Test func backgroundRefreshGetsTheShortDeadline() {
        #expect(WatchDeviceReporter.timeout(for: .backgroundRefresh) == 8)
        #expect(WatchDeviceReporter.timeout(for: .foreground) == 20)
        #expect(WatchDeviceReporter.timeout(for: .settingsChange) == 20)
    }

    @Test func rejectionErrorDescribesWhatWasRejected() {
        let error = WatchDeviceReporterError.sensorsRejected("battery_level: Bad value")

        #expect(error.errorDescription == "Home Assistant rejected battery_level: Bad value")
    }
}
