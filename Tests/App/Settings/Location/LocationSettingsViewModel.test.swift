import CoreLocation
import GRDB
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import Testing
import UIKit

/// Shared state: the view model observes `Current.database`, resolves server names through
/// `Current.servers` and writes the location sources to preferences.
@Suite(.sharedState)
@MainActor
struct LocationSettingsViewModelTests {
    @Test func loadsZonesSortedByNameThenByDistance() async throws {
        try await withZones { servers in
            let viewModel = LocationSettingsViewModel()
            #expect(viewModel.zones.count == 3)
            #expect(viewModel.sortedZones.map(\.name) == ["Home", "Office", "Work"])
            #expect(viewModel.hasMultipleServers)
            #expect(viewModel.formattedDistance(to: viewModel.zones[0]) == nil)

            let home = try #require(viewModel.zones.first { $0.name == "Home" })
            #expect(home.serverName == servers[0].info.name)
            #expect(home.beaconUUID == "B9407F30-F5F8-466E-AFF9-25556B57FE6D")
            #expect(home.beaconMajor == "1")
            #expect(home.beaconMinor == "2")
            #expect(home.formattedCoordinate.contains("52"))

            // A fix near "Work" puts it first.
            viewModel.locationManager(
                CLLocationManager(),
                didUpdateLocations: [CLLocation(latitude: 48.8566, longitude: 2.3522)]
            )
            await #expect(poll { viewModel.currentLocation != nil })
            #expect(viewModel.sortedZones.first?.name == "Work")
            #expect(viewModel.formattedDistance(to: home) != nil)

            // An empty update is ignored.
            viewModel.locationManager(CLLocationManager(), didUpdateLocations: [])
            viewModel.locationManager(CLLocationManager(), didFailWithError: CLError(.locationUnknown))
        }
    }

    @Test func togglesPersistTheLocationSources() async throws {
        try await withZones { _ in
            let previous = Current.settingsStore.locationSources
            defer { Current.settingsStore.locationSources = previous }

            let viewModel = LocationSettingsViewModel()
            viewModel.zoneEnabled = false
            viewModel.backgroundFetchEnabled = false
            viewModel.significantLocationChangeEnabled = false
            viewModel.pushNotificationsEnabled = false
            var sources = Current.settingsStore.locationSources
            #expect(!sources.zone && !sources.backgroundFetch)
            #expect(!sources.significantLocationChange && !sources.pushNotifications)

            viewModel.zoneEnabled = true
            viewModel.pushNotificationsEnabled = true
            sources = Current.settingsStore.locationSources
            #expect(sources.zone && sources.pushNotifications)
        }
    }

    /// The descriptions and disabled states follow whatever the simulator grants.
    @Test func describesTheCurrentPermissions() async throws {
        try await withZones { _ in
            let viewModel = LocationSettingsViewModel()
            viewModel.onAppear()
            viewModel.locationManagerDidChangeAuthorization(CLLocationManager())
            #expect(!viewModel.locationPermissionDescription.isEmpty)
            #expect(!viewModel.locationAccuracyDescription.isEmpty)
            #expect(!viewModel.backgroundRefreshDescription.isEmpty)

            let always = viewModel.locationAuthorizationStatus == .authorizedAlways
            #expect(viewModel.isSignificantLocationChangeToggleDisabled == !always)
            #expect(viewModel.isPushNotificationsToggleDisabled == !always)
            if !always {
                #expect(viewModel.isZoneToggleDisabled)
                #expect(viewModel.isBackgroundFetchToggleDisabled)
            }
        }
    }

    /// Each permission, accuracy and background refresh state reads as its own description, and the
    /// source switches unlock only with "Always" (plus full accuracy for zones and background refresh
    /// for background fetch).
    @Test func describesEveryPermissionState() async throws {
        try await withZones { _ in
            let viewModel = LocationSettingsViewModel()
            let permission = L10n.SettingsDetails.Location.LocationPermission.self
            let expectations: [(CLAuthorizationStatus, String)] = [
                (.authorizedAlways, permission.always),
                (.authorizedWhenInUse, permission.whileInUse),
                (.denied, permission.never),
                (.restricted, permission.never),
                (.notDetermined, permission.needsRequest),
                (CLAuthorizationStatus(rawValue: 99)!, permission.never),
            ]
            for (status, text) in expectations {
                viewModel.locationAuthorizationStatus = status
                #expect(viewModel.locationPermissionDescription == text)
            }

            viewModel.locationAccuracyAuthorization = .reducedAccuracy
            #expect(viewModel.locationAccuracyDescription == L10n.SettingsDetails.Location.LocationAccuracy.reduced)
            viewModel.locationAccuracyAuthorization = CLAccuracyAuthorization(rawValue: 99)!
            #expect(viewModel.locationAccuracyDescription == L10n.SettingsDetails.Location.LocationAccuracy.reduced)

            let refresh = L10n.SettingsDetails.Location.BackgroundRefresh.self
            viewModel.backgroundRefreshStatus = .denied
            #expect(viewModel.backgroundRefreshDescription == refresh.disabled)
            viewModel.backgroundRefreshStatus = UIBackgroundRefreshStatus(rawValue: 99)!
            #expect(viewModel.backgroundRefreshDescription == refresh.disabled)

            viewModel.locationAuthorizationStatus = .authorizedAlways
            viewModel.locationAccuracyAuthorization = .fullAccuracy
            viewModel.backgroundRefreshStatus = .available
            #expect(!viewModel.isZoneToggleDisabled)
            #expect(!viewModel.isBackgroundFetchToggleDisabled)
            viewModel.locationAccuracyAuthorization = .reducedAccuracy
            viewModel.backgroundRefreshStatus = .denied
            #expect(viewModel.isZoneToggleDisabled)
            #expect(viewModel.isBackgroundFetchToggleDisabled)
        }
    }

    /// Without the zones table, the zone list stays empty instead of failing.
    @Test func anUnreadableZoneListStaysEmpty() async throws {
        let previous = Current.database
        defer { Current.database = previous }
        Current.database = { try! DatabaseQueue() }
        let viewModel = LocationSettingsViewModel()
        #expect(viewModel.zones.isEmpty)
    }

    @Test func formatsCoordinatesWithFourDecimals() {
        let text = CoordinateFormatter.string(from: .init(latitude: 1.5, longitude: -2.25))
        #expect(text.contains("1") && text.contains("5000"))
        #expect(text.contains("2500"))
    }

    private func poll(_ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(10)
        while !condition() {
            if Date() > deadline { return false }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        return true
    }

    private func withZones(_ body: ([Server]) async throws -> Void) async throws {
        let database = try DatabaseQueue(path: ":memory:")
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        let servers = FakeServerManager(initial: 2)
        try await database.write { db in
            try AppZone(
                entityId: "zone.home",
                serverIdentifier: servers.all[0].identifier.rawValue,
                friendlyName: "Home",
                latitude: 52.37,
                longitude: 4.89,
                radius: 100,
                beaconUUID: "B9407F30-F5F8-466E-AFF9-25556B57FE6D",
                beaconMajor: 1,
                beaconMinor: 2
            ).insert(db)
            try AppZone(
                entityId: "zone.work",
                serverIdentifier: servers.all[1].identifier.rawValue,
                friendlyName: "Work",
                latitude: 48.85,
                longitude: 2.35,
                radius: 250,
                trackingEnabled: false
            ).insert(db)
            try AppZone(
                entityId: "zone.office",
                serverIdentifier: "unknown-server",
                friendlyName: "Office",
                latitude: 40.71,
                longitude: -74.0,
                radius: 50
            ).insert(db)
        }
        let previousDatabase = Current.database
        let previousServers = Current.servers
        Current.database = { database }
        Current.servers = servers
        defer {
            Current.database = previousDatabase
            Current.servers = previousServers
        }
        try await body(servers.all)
    }
}
