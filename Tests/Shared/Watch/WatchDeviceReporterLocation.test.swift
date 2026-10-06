import CoreLocation
import Foundation
@testable import Shared
import Testing

/// Records the webhook requests a run made, from whichever task the reporter calls `send` on.
private final class LocationSendLog {
    private let lock = NSLock()
    private var sent = [(type: String, server: Identifier<Server>, data: Any)]()
    private var zoneRefreshes = [Identifier<Server>]()

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
        zonesContaining: [AppZone] = []
    ) throws -> WatchDeviceReporter {
        try store.set(registration, for: server.identifier)
        return WatchDeviceReporter(dependencies: .init(
            settings: settings,
            registrations: store,
            servers: { [server] in [server] },
            hasActiveURL: { _ in true },
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
            currentLocation: { _ in location },
            refreshZones: { [log] server, _ in log.recordZoneRefresh(server.identifier) },
            zonesContaining: { _, _ in zonesContaining }
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

    @Test func enteringAZoneWithoutAFixPlacesTheWatchInIt() async throws {
        // The zone the watch is in is worked out from the zone's own centre, standing in for a fix.
        let reporter = try reporter(privacy: .zoneOnly, location: nil, zonesContaining: [home])

        await reporter.report(trigger: .zoneChange, zoneEvent: WatchZoneEvent(zone: home, entered: true))

        let update = try #require(log.locationUpdates(to: server.identifier).first)
        #expect(update["location_name"] as? String == "home")
    }

    @Test func leavingHomeWithoutAFixIsReportedForExact() async throws {
        let reporter = try reporter(privacy: .exact, location: nil)

        await reporter.report(trigger: .zoneChange, zoneEvent: WatchZoneEvent(zone: home, entered: false))

        let update = try #require(log.locationUpdates(to: server.identifier).first)
        #expect(update["location_name"] as? String == LocationNames.NotHome.rawValue)
    }

    @Test func aZoneOfAnotherServerIsNotUsedForThisOne() async throws {
        let otherZone = AppZone(entityId: "zone.home", serverIdentifier: "another-server", radius: 100)
        let reporter = try reporter(privacy: .exact, location: nil)

        let reports = await reporter.report(
            trigger: .zoneChange,
            zoneEvent: WatchZoneEvent(zone: otherZone, entered: false)
        )

        #expect(log.locationUpdates(to: server.identifier).isEmpty)
        #expect(reports.first?.outcome == .skipped(reason: "no location to send"))
    }

    @Test func noFixMeansNothingIsSent() async throws {
        let reporter = try reporter(privacy: .exact, location: nil)

        let reports = await reporter.report(trigger: .settingsChange)

        #expect(log.sends.isEmpty)
        #expect(reports.first?.outcome == .skipped(reason: "no location to send"))
        #expect(settings.lastSensorReportAt == nil)
    }

    @Test func eachTriggerNamesWhatCausedTheReport() {
        #expect(WatchDeviceReporter.locationTrigger(for: .foreground, zoneEvent: nil) == .Launch)
        #expect(WatchDeviceReporter.locationTrigger(for: .backgroundRefresh, zoneEvent: nil) == .BackgroundFetch)
        #expect(WatchDeviceReporter.locationTrigger(for: .settingsChange, zoneEvent: nil) == .Manual)
        #expect(WatchDeviceReporter.locationTrigger(for: .zoneChange, zoneEvent: nil) == .Unknown)
        #expect(
            WatchDeviceReporter.locationTrigger(for: .zoneChange, zoneEvent: WatchZoneEvent(zone: home, entered: false))
                == .GPSRegionExit
        )
    }
}
