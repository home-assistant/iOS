import CoreLocation
import GRDB
@testable import HomeAssistant
@testable import Shared
import SwiftUI
import UIKit
import XCTest

/// Lays the Location settings screens out so SwiftUI evaluates their bodies: the screen with and
/// without zones, the "show all" zones list, a zone card in each of its states and the zone map.
@MainActor
final class LocationSettingsScreensRenderTests: XCTestCase {
    private var previousDatabase: (() -> DatabaseQueue)!
    private var previousServers: ServerManager!
    private var servers: FakeServerManager!

    override func setUp() async throws {
        let database = try DatabaseQueue()
        try AppZoneTable().createIfNeeded(database: database)
        previousDatabase = Current.database
        Current.database = { database }

        previousServers = Current.servers
        servers = FakeServerManager(initial: 2)
        Current.servers = servers

        let firstServer = servers.all[0].identifier.rawValue
        let secondServer = servers.all[1].identifier.rawValue
        try database.write { db in
            try AppZone(
                entityId: "zone.home",
                serverIdentifier: firstServer,
                friendlyName: "Home",
                latitude: 37.3349,
                longitude: -122.0090,
                radius: 100,
                beaconUUID: "B9407F30-F5F8-466E-AFF9-25556B57FE6D",
                beaconMajor: 1,
                beaconMinor: 2
            ).insert(db)
            try AppZone(
                entityId: "zone.office",
                serverIdentifier: secondServer,
                latitude: 37.4,
                longitude: -122.1,
                radius: 250,
                trackingEnabled: false
            ).insert(db)
        }
    }

    override func tearDown() async throws {
        Current.database = previousDatabase
        Current.servers = previousServers
        servers = nil
    }

    /// Deliberately never becomes the key window: the snapshot helpers draw into whatever window is
    /// key, so stealing it here would reach into unrelated tests.
    private func render(_ view: some View, height: CGFloat = 1400) async {
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: height))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        // `onAppear` and the state it publishes land after the first pass.
        try? await Task.sleep(nanoseconds: 50_000_000)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        XCTAssertNotNil(controller.view)

        window.isHidden = true
        window.rootViewController = nil
    }

    func testRendersTheScreenWithZones() async {
        await render(NavigationView { LocationSettingsView() }, height: 2400)
    }

    func testRendersTheScreenWithoutZones() async throws {
        try Current.database().write { db in
            _ = try AppZone.deleteAll(db)
        }
        await render(NavigationView { LocationSettingsView() }, height: 2400)
    }

    func testRendersTheZonesListForSeveralServers() async {
        let viewModel = LocationSettingsViewModel()
        XCTAssertEqual(viewModel.zones.count, 2)
        XCTAssertTrue(viewModel.hasMultipleServers)

        await render(NavigationView { ZonesListView(viewModel: viewModel) }, height: 1800)
    }

    func testRendersZoneCardsWithAndWithoutOptionalDetails() async {
        let beaconZone = LocationZoneItem(zone: AppZone(
            entityId: "zone.home",
            serverIdentifier: servers.all[0].identifier.rawValue,
            friendlyName: "Home",
            latitude: 37.3349,
            longitude: -122.0090,
            radius: 100,
            beaconUUID: "B9407F30-F5F8-466E-AFF9-25556B57FE6D",
            beaconMajor: 1,
            beaconMinor: 2
        ))
        let plainZone = LocationZoneItem(zone: AppZone(
            entityId: "zone.office",
            serverIdentifier: "unknown",
            radius: 20,
            trackingEnabled: false
        ))

        await render(
            List {
                ZoneCardView(zone: beaconZone, distanceText: "1.2 km", serverName: "Home server")
                ZoneCardView(zone: plainZone, distanceText: nil, serverName: nil)
            },
            height: 1200
        )
    }

    func testRendersTheZoneMapWithAndWithoutATitle() async {
        await render(NavigationView {
            LocationZoneMapView(
                title: "Home",
                coordinate: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090),
                radius: 50
            )
        })
        await render(NavigationView {
            LocationZoneMapView(
                title: "",
                coordinate: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090),
                radius: 500
            )
        })
    }

    func testRendersAPermissionStatusRow() async {
        var tapped = false
        let row = LocationPermissionStatusRow(title: "Location", value: "Always") { tapped = true }
        row.action()
        XCTAssertTrue(tapped)

        await render(List { row })
    }

    func testSearchEntriesCoverTheScreensRows() {
        let titles = LocationSettingsView.settingsSearchEntries.map(\.title)

        XCTAssertTrue(titles.contains(L10n.SettingsDetails.Location.LocationPermission.title))
        XCTAssertTrue(titles.contains(L10n.SettingsDetails.Location.Zones.header))
        XCTAssertEqual(titles.count, 9)
    }
}
