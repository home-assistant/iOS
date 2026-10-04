import CoreLocation
import GRDB
@testable import HomeAssistant
@testable import Shared
import XCTest

/// The Location settings screen lists the zones stored in the database, orders them by distance
/// once a fix arrives, and writes its update-source switches straight into the settings store.
@MainActor
final class LocationSettingsViewModelTests: XCTestCase {
    private var database: DatabaseQueue!
    private var previousDatabase: (() -> DatabaseQueue)!
    private var previousServers: ServerManager!
    private var previousLocationSources: SettingsStore.LocationSource!
    private var servers: FakeServerManager!

    override func setUp() async throws {
        let database = try DatabaseQueue()
        try AppZoneTable().createIfNeeded(database: database)
        self.database = database
        previousDatabase = Current.database
        Current.database = { database }

        previousServers = Current.servers
        servers = FakeServerManager(initial: 1)
        Current.servers = servers

        previousLocationSources = Current.settingsStore.locationSources
    }

    override func tearDown() async throws {
        Current.settingsStore.locationSources = previousLocationSources
        Current.database = previousDatabase
        Current.servers = previousServers
        database = nil
        servers = nil
    }

    private func insertZones(_ zones: [AppZone]) throws {
        try database.write { db in
            for zone in zones {
                try zone.insert(db)
            }
        }
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0 ..< 200 where !condition() {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    func testZonesAreLoadedFromTheDatabaseAndSortedByNameWithoutAFix() throws {
        let serverIdentifier = servers.all[0].identifier.rawValue
        try insertZones([
            AppZone(
                entityId: "zone.work",
                serverIdentifier: serverIdentifier,
                friendlyName: "Work",
                latitude: 37.2,
                longitude: -122.2,
                radius: 100
            ),
            AppZone(
                entityId: "zone.home",
                serverIdentifier: serverIdentifier,
                friendlyName: "Home",
                latitude: 37.1,
                longitude: -122.1,
                radius: 50,
                trackingEnabled: false,
                beaconUUID: "B9407F30-F5F8-466E-AFF9-25556B57FE6D",
                beaconMajor: 12,
                beaconMinor: 34
            ),
        ])

        let viewModel = LocationSettingsViewModel()

        XCTAssertEqual(viewModel.zones.count, 2)
        XCTAssertEqual(viewModel.sortedZones.map(\.name), ["Home", "Work"])
        XCTAssertNil(viewModel.currentLocation)

        let home = try XCTUnwrap(viewModel.zones.first(where: { $0.name == "Home" }))
        XCTAssertFalse(home.trackingEnabled)
        XCTAssertEqual(home.radius, 50)
        XCTAssertEqual(home.serverIdentifier, serverIdentifier)
        XCTAssertEqual(home.serverName, servers.all[0].info.name)
        XCTAssertEqual(home.beaconUUID, "B9407F30-F5F8-466E-AFF9-25556B57FE6D")
        XCTAssertEqual(home.beaconMajor, "12")
        XCTAssertEqual(home.beaconMinor, "34")
        XCTAssertFalse(home.formattedCoordinate.isEmpty)
        XCTAssertTrue(home.formattedCoordinate.contains(", "))
        XCTAssertNil(viewModel.formattedDistance(to: home))

        let work = try XCTUnwrap(viewModel.zones.first(where: { $0.name == "Work" }))
        XCTAssertTrue(work.trackingEnabled)
        XCTAssertNil(work.beaconUUID)
        XCTAssertNil(work.beaconMajor)
        XCTAssertNil(work.beaconMinor)
    }

    func testAZoneOfAnUnknownServerHasNoServerName() throws {
        try insertZones([
            AppZone(entityId: "zone.elsewhere", serverIdentifier: "not-a-server"),
        ])

        let viewModel = LocationSettingsViewModel()

        XCTAssertEqual(viewModel.zones.count, 1)
        XCTAssertNil(viewModel.zones[0].serverName)
        XCTAssertEqual(viewModel.zones[0].name, "Elsewhere")
    }

    func testZonesAreSortedByDistanceOnceAFixArrives() async throws {
        let serverIdentifier = servers.all[0].identifier.rawValue
        try insertZones([
            AppZone(
                entityId: "zone.aaa_far",
                serverIdentifier: serverIdentifier,
                friendlyName: "Far",
                latitude: 10,
                longitude: 10,
                radius: 100
            ),
            AppZone(
                entityId: "zone.zzz_near",
                serverIdentifier: serverIdentifier,
                friendlyName: "Near",
                latitude: 0.001,
                longitude: 0.001,
                radius: 100
            ),
        ])

        let viewModel = LocationSettingsViewModel()
        XCTAssertEqual(viewModel.sortedZones.map(\.name), ["Far", "Near"])

        viewModel.locationManager(
            CLLocationManager(),
            didUpdateLocations: [CLLocation(latitude: 0, longitude: 0)]
        )
        try await waitUntil { viewModel.currentLocation != nil }

        XCTAssertNotNil(viewModel.currentLocation)
        XCTAssertEqual(viewModel.sortedZones.map(\.name), ["Near", "Far"])
        let near = try XCTUnwrap(viewModel.zones.first(where: { $0.name == "Near" }))
        let distance = try XCTUnwrap(viewModel.formattedDistance(to: near))
        XCTAssertFalse(distance.isEmpty)
    }

    func testAnEmptyLocationUpdateKeepsTheZonesAlphabetical() async throws {
        let viewModel = LocationSettingsViewModel()

        viewModel.locationManager(CLLocationManager(), didUpdateLocations: [])
        viewModel.locationManager(CLLocationManager(), didFailWithError: URLError(.cannotFindHost))
        try await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertNil(viewModel.currentLocation)
        XCTAssertTrue(viewModel.zones.isEmpty)
        XCTAssertTrue(viewModel.sortedZones.isEmpty)
    }

    func testZonesAddedLaterAreObserved() async throws {
        let viewModel = LocationSettingsViewModel()
        XCTAssertTrue(viewModel.zones.isEmpty)

        try insertZones([
            AppZone(entityId: "zone.gym", serverIdentifier: servers.all[0].identifier.rawValue),
        ])
        try await waitUntil { !viewModel.zones.isEmpty }

        XCTAssertEqual(viewModel.zones.map(\.name), ["Gym"])
    }

    func testHasMultipleServersFollowsTheServerManager() {
        let viewModel = LocationSettingsViewModel()
        XCTAssertFalse(viewModel.hasMultipleServers)

        servers.addFake()
        XCTAssertTrue(viewModel.hasMultipleServers)
    }

    func testTogglesStartFromAndWriteToTheStoredLocationSources() {
        Current.settingsStore.locationSources = .init(
            zone: true,
            backgroundFetch: false,
            significantLocationChange: true,
            pushNotifications: false
        )

        let viewModel = LocationSettingsViewModel()
        XCTAssertTrue(viewModel.zoneEnabled)
        XCTAssertFalse(viewModel.backgroundFetchEnabled)
        XCTAssertTrue(viewModel.significantLocationChangeEnabled)
        XCTAssertFalse(viewModel.pushNotificationsEnabled)

        viewModel.zoneEnabled = false
        XCTAssertFalse(Current.settingsStore.locationSources.zone)

        viewModel.backgroundFetchEnabled = true
        XCTAssertTrue(Current.settingsStore.locationSources.backgroundFetch)

        viewModel.significantLocationChangeEnabled = false
        XCTAssertFalse(Current.settingsStore.locationSources.significantLocationChange)

        viewModel.pushNotificationsEnabled = true
        XCTAssertTrue(Current.settingsStore.locationSources.pushNotifications)
    }

    /// The simulator decides the actual permission, so these check the toggles are disabled exactly
    /// when the permission they depend on is missing, whatever it currently is.
    func testDisabledStatesFollowThePermissions() {
        let viewModel = LocationSettingsViewModel()
        viewModel.onAppear()
        viewModel.locationManagerDidChangeAuthorization(CLLocationManager())

        let isAlways = viewModel.locationAuthorizationStatus == .authorizedAlways
        let isFull = viewModel.locationAccuracyAuthorization == .fullAccuracy
        let isRefreshAvailable = viewModel.backgroundRefreshStatus == .available

        XCTAssertEqual(viewModel.isSignificantLocationChangeToggleDisabled, !isAlways)
        XCTAssertEqual(viewModel.isPushNotificationsToggleDisabled, !isAlways)
        XCTAssertEqual(viewModel.isZoneToggleDisabled, !isAlways || !isFull)
        XCTAssertEqual(viewModel.isBackgroundFetchToggleDisabled, !isAlways || !isRefreshAvailable)

        XCTAssertFalse(viewModel.locationPermissionDescription.isEmpty)
        XCTAssertFalse(viewModel.locationAccuracyDescription.isEmpty)
        XCTAssertFalse(viewModel.backgroundRefreshDescription.isEmpty)
    }

    func testCoordinateFormatterUsesFourFractionDigits() {
        let formatted = CoordinateFormatter.string(from: CLLocationCoordinate2D(latitude: 1, longitude: 2))
        let parts = formatted.components(separatedBy: ", ")

        XCTAssertEqual(parts.count, 2)
        XCTAssertEqual(parts.first?.count, 6)
        XCTAssertEqual(parts.last?.count, 6)
    }
}
