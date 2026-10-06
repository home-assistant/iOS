import CoreLocation
import Foundation
@testable import Shared
import Testing

/// Records the webhook requests a run made, from whichever task the reporter calls `send` on.
private final class LocationSendLog {
    private let lock = NSLock()
    private var sent = [(type: String, server: Identifier<Server>, data: Any)]()
    private var zoneRefreshes = [Identifier<Server>]()
    private var fixRequests = 0
    private var clearPending = false

    var locationFixRequests: Int {
        lock.lock()
        defer { lock.unlock() }
        return fixRequests
    }

    var isClearPending: Bool {
        lock.lock()
        defer { lock.unlock() }
        return clearPending
    }

    func recordFixRequest() {
        lock.lock()
        defer { lock.unlock() }
        fixRequests += 1
    }

    func setClearPending(_ pending: Bool) {
        lock.lock()
        defer { lock.unlock() }
        clearPending = pending
    }

    var sends: [(type: String, server: Identifier<Server>, data: Any)] {
        lock.lock()
        defer { lock.unlock() }
        return sent
    }

    var refreshedZones: [Identifier<Server>] {
        lock.lock()
        defer { lock.unlock() }
        return zoneRefreshes
    }

    func locationUpdates(to server: Identifier<Server>) -> [[String: Any]] {
        sends.filter { $0.type == "update_location" && $0.server == server }.compactMap { $0.data as? [String: Any] }
    }

    func record(type: String, server: Identifier<Server>, data: Any) {
        lock.lock()
        defer { lock.unlock() }
        sent.append((type, server, data))
    }

    func recordZoneRefresh(_ server: Identifier<Server>) {
        lock.lock()
        defer { lock.unlock() }
        zoneRefreshes.append(server)
    }
}

// Serialized: the suites share `Current`.
@Suite(.serialized)
struct WatchDeviceReporterLocationTests {
    private let server = Server.fake { $0.version = .inZonesOnLocationUpdate }
    private let store = FakeWatchDeviceRegistrationStore()
    private let settings = InMemoryWatchSensorSettings()
    private let log = LocationSendLog()
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private let fix = CLLocation(
        coordinate: .init(latitude: 52.37, longitude: 4.89),
        altitude: 2,
        horizontalAccuracy: 8,
        verticalAccuracy: 4,
        timestamp: Date(timeIntervalSince1970: 1_800_000_000)
    )
    private var home: AppZone {
        AppZone(
            entityId: "zone.home",
            serverIdentifier: server.identifier.rawValue,
            latitude: 52.37,
            longitude: 4.89,
            radius: 100
        )
    }

    init() {
        Current.device.batteries = { [DeviceBattery(level: 80, state: .charging, attributes: [:])] }
    }

    private var registration: WatchDeviceRegistration {
        WatchDeviceRegistration(
            webhookID: "watch-hook",
            webhookSecret: nil,
            cloudhookURL: nil,
            registeredAt: now,
            deviceName: "My iPhone Apple Watch",
            registeredAppVersion: AppConstants.version
        )
    }

    private func reporter(
        privacy: ServerLocationPrivacy,
        location: CLLocation?,
        zonesContaining: [AppZone] = [],
        hasActiveURL: Bool = true,
        hasZones: Bool = true
    ) throws -> WatchDeviceReporter {
        try store.set(registration, for: server.identifier)
        return WatchDeviceReporter(dependencies: .init(
            settings: settings,
            registrations: store,
            servers: { [server] in [server] },
            hasActiveURL: { _ in hasActiveURL },
            // No sensors, so every request a run makes is about the location.
            currentSensors: { [] },
            identity: { _ in
                WatchDeviceIdentity(
                    appID: "io.robbie.HomeAssistant.watchkitapp",
                    appName: "Home Assistant Watch",
                    appVersion: "2026.1 (1)",
                    deviceName: "My iPhone Apple Watch",
                    deviceID: "watch-device-id",
                    model: "Watch7,1",
                    osName: "watchOS",
                    osVersion: "26.0"
                )
            },
            register: { _, _ in Issue.record("already registered"); throw CancellationError() },
            send: { [log] type, data, server, _, _ in
                log.record(type: type, server: server.identifier, data: data)
                return [String: Any]()
            },
            now: { [now] in now },
            locationPrivacy: { _ in privacy },
            currentLocation: { [log] _ in
                log.recordFixRequest()
                return location
            },
            refreshZones: { [log] server, _ in
                log.recordZoneRefresh(server.identifier)
                return hasZones
            },
            zonesContaining: { _, _ in zonesContaining },
            isLocationClearPending: { [log] _ in log.isClearPending },
            locationCleared: { [log] _ in log.setClearPending(false) }
        ))
    }

    @Test func nothingIsSentWhenTheUserDidNotOptIn() async throws {
        let reporter = try reporter(privacy: .never, location: fix)

        let reports = await reporter.report(trigger: .settingsChange)

        #expect(reports == [.init(server: server.identifier, outcome: .nothingEnabled)])
        #expect(log.sends.isEmpty)
        #expect(log.refreshedZones.isEmpty)
    }

    @Test func exactSendsTheFix() async throws {
        let reporter = try reporter(privacy: .exact, location: fix)

        let reports = await reporter.report(trigger: .backgroundRefresh)

        #expect(reports == [.init(server: server.identifier, outcome: .reported(sensorCount: 0, locationSent: true))])
        let update = try #require(log.locationUpdates(to: server.identifier).first)
        #expect(update["gps"] as? [Double] == [52.37, 4.89])
        #expect(update["gps_accuracy"] as? Double == 8)
        #expect(settings.lastSensorReportAt == now)
    }

    @Test func zoneOnlySendsTheZoneAndNoCoordinates() async throws {
        let reporter = try reporter(privacy: .zoneOnly, location: fix, zonesContaining: [home])

        await reporter.report(trigger: .foreground)

        let update = try #require(log.locationUpdates(to: server.identifier).first)
        #expect(update["gps"] == nil)
        #expect(update["location_name"] as? String == "home")
        #expect(update["in_zones"] as? [String] == ["zone.home"])
        #expect(log.refreshedZones == [server.identifier])
    }

    @Test func noFixMeansNothingIsSent() async throws {
        let reporter = try reporter(privacy: .exact, location: nil)

        let reports = await reporter.report(trigger: .settingsChange)

        #expect(log.sends.isEmpty)
        #expect(reports.first?.outcome == .skipped(reason: "no location to send"))
        #expect(settings.lastSensorReportAt == nil)
    }

    @Test func exactLeavesOutTheZones() async throws {
        let reporter = try reporter(privacy: .exact, location: fix, zonesContaining: [home])

        await reporter.report(trigger: .foreground)

        let update = try #require(log.locationUpdates(to: server.identifier).first)
        #expect(update["location_name"] == nil)
        #expect(update["in_zones"] == nil)
        // Exact reports don't use the zones, so they aren't fetched.
        #expect(log.refreshedZones.isEmpty)
    }

    @Test func zoneOnlySendsNothingBeforeTheZonesArrive() async throws {
        // Without the zones every report would say the watch is away, home or not.
        let reporter = try reporter(privacy: .zoneOnly, location: fix, hasZones: false)

        let reports = await reporter.report(trigger: .foreground)

        #expect(log.locationUpdates(to: server.identifier).isEmpty)
        #expect(reports.first?.outcome == .skipped(reason: "no location to send"))
    }

    @Test func noFixIsTakenWhenNoServerCanBeReached() async throws {
        let reporter = try reporter(privacy: .exact, location: fix, hasActiveURL: false)

        let reports = await reporter.report(trigger: .foreground)

        #expect(log.locationFixRequests == 0)
        #expect(reports.first?.outcome == .skipped(reason: "no active URL"))
    }

    @Test func switchingToNeverReplacesTheLastLocationOnce() async throws {
        log.setClearPending(true)
        let reporter = try reporter(privacy: .never, location: fix)

        let first = await reporter.report(trigger: .settingsChange)
        let second = await reporter.report(trigger: .settingsChange)

        let updates = log.locationUpdates(to: server.identifier)
        #expect(updates.count == 1)
        let update = try #require(updates.first)
        #expect(update["gps"] == nil)
        #expect(update["location_name"] == nil)
        #expect(update["battery"] as? Int == 80)
        #expect(!log.isClearPending)
        #expect(first.first?.outcome == .reported(sensorCount: 0, locationSent: true))
        #expect(second.first?.outcome == .nothingEnabled)
        // Nothing about where the watch is was asked for.
        #expect(log.locationFixRequests == 0)
    }

    @Test func aFailedClearIsTriedAgain() async throws {
        log.setClearPending(true)
        try store.set(registration, for: server.identifier)
        let reporter = WatchDeviceReporter(dependencies: .init(
            settings: settings,
            registrations: store,
            servers: { [server] in [server] },
            hasActiveURL: { _ in true },
            currentSensors: { [] },
            identity: { _ in
                WatchDeviceIdentity(
                    appID: "io.robbie.HomeAssistant.watchkitapp",
                    appName: "Home Assistant Watch",
                    appVersion: "2026.1 (1)",
                    deviceName: "My iPhone Apple Watch",
                    deviceID: "watch-device-id",
                    model: "Watch7,1",
                    osName: "watchOS",
                    osVersion: "26.0"
                )
            },
            register: { _, _ in Issue.record("already registered"); throw CancellationError() },
            send: { _, _, _, _, _ in throw URLError(.notConnectedToInternet) },
            now: { [now] in now },
            locationPrivacy: { _ in .never },
            isLocationClearPending: { [log] _ in log.isClearPending },
            locationCleared: { [log] _ in log.setClearPending(false) }
        ))

        let reports = await reporter.report(trigger: .backgroundRefresh)

        #expect(log.isClearPending)
        if case .failed = reports.first?.outcome {} else {
            Issue.record("expected a failure, got \(String(describing: reports.first?.outcome))")
        }
    }

    @Test func eachTriggerNamesWhatCausedTheReport() {
        #expect(WatchDeviceReporter.locationTrigger(for: .foreground) == .Launch)
        #expect(WatchDeviceReporter.locationTrigger(for: .backgroundRefresh) == .BackgroundFetch)
        #expect(WatchDeviceReporter.locationTrigger(for: .settingsChange) == .Manual)
    }
}
