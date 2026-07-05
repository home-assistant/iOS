import CoreLocation
import Foundation
import RealmSwift
@testable import Shared
import XCTest

class LocationBasedServerSwitcherTests: XCTestCase {
    private var servers: FakeServerManager!
    private var serverA: Server!
    private var serverB: Server!
    private var prefs: UserDefaults!
    private var prefsSuiteName: String!

    // gus's, mission bay
    private let zoneACenter = CLLocationCoordinate2D(latitude: 37.774299403042754, longitude: -122.3914772411471)
    // gus's, mission
    private let zoneBCenter = CLLocationCoordinate2D(latitude: 37.76421375578578, longitude: -122.41263128786335)

    override func setUpWithError() throws {
        try super.setUpWithError()

        servers = FakeServerManager()
        serverA = servers.add(identifier: "serverA", serverInfo: with(ServerInfo.fake()) {
            $0.connection.internalSSIDs = ["wifi-a"]
        })
        serverB = servers.add(identifier: "serverB", serverInfo: with(ServerInfo.fake()) {
            $0.connection.internalSSIDs = ["wifi-b"]
        })
        Current.servers = servers

        prefsSuiteName = "LocationBasedServerSwitcherTests-\(UUID().uuidString)"
        prefs = UserDefaults(suiteName: prefsSuiteName)

        Current.settingsStore.locationBasedServerSwitchEnabled = true
        Current.connectivity.currentWiFiSSID = { nil }
        Current.connectivity.currentNetworkHardwareAddress = { nil }

        let executionIdentifier = UUID().uuidString
        let realm = try Realm(configuration: .init(inMemoryIdentifier: executionIdentifier))
        Current.realm = { realm }

        try realm.write {
            realm.add(with(RLMZone()) {
                $0.entityId = "zone.home"
                $0.serverIdentifier = "serverA"
                $0.Latitude = zoneACenter.latitude
                $0.Longitude = zoneACenter.longitude
                $0.Radius = 100.0
            })
            realm.add(with(RLMZone()) {
                $0.entityId = "zone.home"
                $0.serverIdentifier = "serverB"
                $0.Latitude = zoneBCenter.latitude
                $0.Longitude = zoneBCenter.longitude
                $0.Radius = 100.0
            })
        }
    }

    override func tearDown() {
        Current.settingsStore.locationBasedServerSwitchEnabled = false
        Current.connectivity.currentWiFiSSID = { nil }
        Current.connectivity.currentNetworkHardwareAddress = { nil }
        Current.realm = Realm.live
        Current.servers = FakeServerManager()
        Current.date = Date.init
        prefs.removePersistentDomain(forName: prefsSuiteName)
        super.tearDown()
    }

    private func makeSwitcher(
        gracePeriod: TimeInterval = LocationBasedServerSwitcherImpl.defaultGracePeriod,
        locationAuthorization: CLAuthorizationStatus = .denied,
        oneShotLocation: (() async throws -> CLLocation)? = nil
    ) -> LocationBasedServerSwitcherImpl {
        LocationBasedServerSwitcherImpl(
            prefs: prefs,
            gracePeriod: gracePeriod,
            refreshNetworkInformation: {},
            locationAuthorization: { locationAuthorization },
            oneShotLocation: oneShotLocation ?? { throw OneShotError.outOfTime }
        )
    }

    private func location(at coordinate: CLLocationCoordinate2D) -> CLLocation {
        CLLocation(
            coordinate: coordinate,
            altitude: 0,
            horizontalAccuracy: 10,
            verticalAccuracy: 10,
            timestamp: Current.date()
        )
    }

    // MARK: - Enablement

    func testDisabledWhenSettingIsOff() async {
        Current.settingsStore.locationBasedServerSwitchEnabled = false
        Current.connectivity.currentWiFiSSID = { "wifi-a" }

        let switcher = makeSwitcher()
        XCTAssertFalse(switcher.isEnabled)
        XCTAssertNil(switcher.preferredServerUsingCachedState())

        let preferred = await switcher.preferredServer()
        XCTAssertNil(preferred)
    }

    func testDisabledWithSingleServer() async {
        servers.remove(identifier: serverB.identifier)
        Current.connectivity.currentWiFiSSID = { "wifi-a" }

        let switcher = makeSwitcher()
        XCTAssertFalse(switcher.isEnabled)

        let preferred = await switcher.preferredServer()
        XCTAssertNil(preferred)
    }

    // MARK: - Network (SSID) matching

    func testSSIDMatchPicksServer() async {
        Current.connectivity.currentWiFiSSID = { "wifi-b" }

        let switcher = makeSwitcher()
        XCTAssertEqual(switcher.preferredServerUsingCachedState()?.identifier, serverB.identifier)

        let preferred = await switcher.preferredServer()
        XCTAssertEqual(preferred?.identifier, serverB.identifier)
    }

    func testAmbiguousSSIDMatchPicksNothing() async {
        serverA.update { $0.connection.internalSSIDs = ["shared-wifi"] }
        serverB.update { $0.connection.internalSSIDs = ["shared-wifi"] }
        Current.connectivity.currentWiFiSSID = { "shared-wifi" }

        let switcher = makeSwitcher()
        XCTAssertNil(switcher.preferredServerUsingCachedState())

        let preferred = await switcher.preferredServer()
        XCTAssertNil(preferred)
    }

    // MARK: - Zone matching

    func testFreshLocationInsideZonePicksServer() async {
        let switcher = makeSwitcher(
            locationAuthorization: .authorizedWhenInUse,
            oneShotLocation: { [self] in location(at: zoneBCenter) }
        )

        let preferred = await switcher.preferredServer()
        XCTAssertEqual(preferred?.identifier, serverB.identifier)
    }

    func testFreshLocationOutsideAllZonesPicksNothing() async {
        // fort mason, sf — inside no configured zone
        let switcher = makeSwitcher(
            locationAuthorization: .authorizedWhenInUse,
            oneShotLocation: { [self] in
                location(at: .init(latitude: 37.80535, longitude: -122.43194))
            }
        )

        let preferred = await switcher.preferredServer()
        XCTAssertNil(preferred)
    }

    func testFailedLocationFallsBackToCachedZoneState() async throws {
        let realm = Current.realm()
        try realm.write {
            realm.objects(RLMZone.self)
                .first(where: { $0.serverIdentifier == "serverA" })?
                .inRegion = true
        }

        let switcher = makeSwitcher(
            locationAuthorization: .authorizedWhenInUse,
            oneShotLocation: { throw OneShotError.outOfTime }
        )

        let preferred = await switcher.preferredServer()
        XCTAssertEqual(preferred?.identifier, serverA.identifier)
    }

    func testWithoutLocationPermissionUsesCachedZoneState() async throws {
        let realm = Current.realm()
        try realm.write {
            realm.objects(RLMZone.self)
                .first(where: { $0.serverIdentifier == "serverB" })?
                .inRegion = true
        }

        let switcher = makeSwitcher(locationAuthorization: .denied)

        let preferred = await switcher.preferredServer()
        XCTAssertEqual(preferred?.identifier, serverB.identifier)

        XCTAssertEqual(switcher.preferredServerUsingCachedState()?.identifier, serverB.identifier)
    }

    func testAmbiguousZoneStatePicksNothing() async throws {
        let realm = Current.realm()
        try realm.write {
            for zone in realm.objects(RLMZone.self) {
                zone.inRegion = true
            }
        }

        let switcher = makeSwitcher(locationAuthorization: .denied)

        let preferred = await switcher.preferredServer()
        XCTAssertNil(preferred)
    }

    // MARK: - Manual selection grace period

    func testManualSelectionActiveWithinGracePeriod() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        Current.date = { start }

        let switcher = makeSwitcher(gracePeriod: 15 * 60)
        switcher.recordManualSelection(of: serverB)

        XCTAssertEqual(switcher.activeManualSelection?.identifier, serverB.identifier)
        XCTAssertTrue(switcher.isManualSelectionActive(for: serverB))
        XCTAssertFalse(switcher.isManualSelectionActive(for: serverA))

        // just before expiration
        Current.date = { start.addingTimeInterval(15 * 60 - 1) }
        XCTAssertTrue(switcher.isManualSelectionActive(for: serverB))

        // after expiration
        Current.date = { start.addingTimeInterval(15 * 60) }
        XCTAssertNil(switcher.activeManualSelection)
        XCTAssertFalse(switcher.isManualSelectionActive(for: serverB))
    }

    func testManualSelectionOfRemovedServerIsIgnored() {
        let switcher = makeSwitcher()
        switcher.recordManualSelection(of: serverB)
        servers.remove(identifier: serverB.identifier)

        XCTAssertNil(switcher.activeManualSelection)
    }

    func testManualSelectionIsReplacedByNewerSelection() {
        let switcher = makeSwitcher()
        switcher.recordManualSelection(of: serverB)
        switcher.recordManualSelection(of: serverA)

        XCTAssertEqual(switcher.activeManualSelection?.identifier, serverA.identifier)
        XCTAssertFalse(switcher.isManualSelectionActive(for: serverB))
    }
}
