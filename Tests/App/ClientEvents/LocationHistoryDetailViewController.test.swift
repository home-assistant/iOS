import CoreLocation
import GRDB
@testable import HomeAssistant
import MapKit
@testable import Shared
import SwiftUI
import UIKit
import XCTest

@MainActor
final class LocationHistoryDetailViewControllerTests: XCTestCase {
    private var previousDatabase: (() -> DatabaseQueue)!
    private var previousDate: (() -> Date)!
    private var entries: [LocationHistoryEntry] = []
    private var window: UIWindow?

    override func setUpWithError() throws {
        try super.setUpWithError()
        previousDatabase = Current.database
        previousDate = Current.date

        let database = try DatabaseQueue()
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }

        // Oldest first; the screen lists newest first.
        entries = [
            entry(at: 100, latitude: 52.37, accuracy: 65, trigger: .Manual),
            entry(at: 200, latitude: 52.38, accuracy: 1414, trigger: .RegionEnter),
            entry(at: 300, latitude: 52.39, accuracy: 20, trigger: .Periodic),
        ]
        let zones = [
            AppZone(entityId: "zone.home", serverIdentifier: "server", latitude: 52.38, longitude: 4.9, radius: 50),
            AppZone(entityId: "zone.work", serverIdentifier: "server", latitude: 52.40, longitude: 4.9, radius: 250),
        ]
        try database.write { db in
            for entry in entries {
                try entry.insert(db)
            }
            for zone in zones {
                try zone.insert(db)
            }
        }
        Current.database = { database }
    }

    override func tearDown() {
        if let window {
            window.rootViewController?.dismiss(animated: false)
            window.isHidden = true
            window.rootViewController = nil
        }
        window = nil
        Current.database = previousDatabase
        Current.date = previousDate
        super.tearDown()
    }

    func testShowsTheEntryOnTheMap() throws {
        let sut = LocationHistoryDetailViewController(currentEntry: entries[1])
        show(sut)

        XCTAssertEqual(sut.title, title(for: entries[1]))
        XCTAssertEqual(sut.navigationItem.title, sut.title)
        XCTAssertEqual(sut.navigationItem.rightBarButtonItems?.count, 2)
        XCTAssertEqual(sut.toolbarItems?.count, 5)

        let map = try XCTUnwrap(sut.view.subviews.compactMap { $0 as? MKMapView }.first)
        XCTAssertEqual(map.annotations.count, 1)
        // home is under 100m, so only its zone circle; work also shows its monitored regions; plus GPS.
        XCTAssertGreaterThanOrEqual(map.overlays.count, 3)
        XCTAssertEqual(map.annotations.first?.coordinate.latitude ?? 0, 52.38, accuracy: 0.0001)

        for overlay in map.overlays {
            let renderer = try XCTUnwrap(sut.mapView(map, rendererFor: overlay) as? MKCircleRenderer)
            XCTAssertNotNil(renderer.fillColor)
        }
        let annotation = try XCTUnwrap(map.annotations.first)
        let marker = try XCTUnwrap(sut.mapView(map, viewFor: annotation) as? MKMarkerAnnotationView)
        XCTAssertEqual(marker.markerTintColor, .purple)
    }

    func testMovesThroughTheHistory() throws {
        let sut = LocationHistoryDetailViewController(currentEntry: entries[1])
        show(sut)
        waitForEntries()

        try trigger("moveUp:", on: sut)
        XCTAssertEqual(sut.title, title(for: entries[2]), "up is the newer entry")
        XCTAssertEqual(try button("moveUp:", in: sut).isEnabled, false)
        XCTAssertEqual(try button("moveDown:", in: sut).isEnabled, true)

        try trigger("moveUp:", on: sut)
        XCTAssertEqual(sut.title, title(for: entries[2]), "there is nothing newer")

        try trigger("moveDown:", on: sut)
        try trigger("moveDown:", on: sut)
        XCTAssertEqual(sut.title, title(for: entries[0]))
        XCTAssertEqual(try button("moveUp:", in: sut).isEnabled, true)
        XCTAssertEqual(try button("moveDown:", in: sut).isEnabled, false)

        try trigger("center:", on: sut)
        let map = try XCTUnwrap(sut.view.subviews.compactMap { $0 as? MKMapView }.first)
        XCTAssertEqual(map.annotations.first?.coordinate.latitude ?? 0, 52.37, accuracy: 0.0001)
    }

    func testHelpExplainsTheScreen() throws {
        let sut = LocationHistoryDetailViewController(currentEntry: entries[0])
        show(sut)

        try trigger("help:", on: sut)

        let alert = try XCTUnwrap(sut.presentedViewController as? UIAlertController)
        XCTAssertEqual(alert.message, L10n.Settings.LocationHistory.Detail.explanation)
    }

    func testShareOffersTheMapAndReport() throws {
        let sut = LocationHistoryDetailViewController(currentEntry: entries[2])
        show(sut)

        try trigger("share:", on: sut)

        XCTAssertTrue(sut.presentedViewController is UIActivityViewController)
    }

    func testDismissCallbackFiresWhenTheScreenGoesAway() {
        let sut = LocationHistoryDetailViewController(currentEntry: entries[0])
        var dismissed: UIViewController?
        sut.onDismissCallback = { dismissed = $0 }

        sut.viewWillDisappear(false)

        XCTAssertIdentical(dismissed, sut)
    }

    func testWrapperHostsTheControllerInSwiftUI() {
        let controller = UIHostingController(rootView: NavigationView {
            LocationHistoryDetailViewControllerWrapper(currentEntry: entries[1])
        }.navigationViewStyle(.stack))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.isHidden = false
        self.window = window
        controller.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))

        XCTAssertNotNil(Self.find(LocationHistoryDetailViewController.self, from: controller))
    }

    // MARK: - Helpers

    private func entry(
        at time: TimeInterval,
        latitude: Double,
        accuracy: CLLocationAccuracy,
        trigger: LocationUpdateTrigger
    ) -> LocationHistoryEntry {
        Current.date = { Date(timeIntervalSince1970: time) }
        return LocationHistoryEntry(
            updateType: trigger,
            location: CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: 4.9),
                altitude: 0,
                horizontalAccuracy: accuracy,
                verticalAccuracy: 0,
                timestamp: Date(timeIntervalSince1970: time)
            ),
            zone: nil,
            accuracyAuthorization: .fullAccuracy,
            payload: #"{"time": \#(Int(time))}"#
        )
    }

    private func title(for entry: LocationHistoryEntry) -> String {
        DateFormatter.localizedString(from: entry.createdAt, dateStyle: .short, timeStyle: .medium)
    }

    private func show(_ controller: UIViewController) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = UINavigationController(rootViewController: controller)
        window.isHidden = false
        self.window = window
        controller.loadViewIfNeeded()
        controller.view.layoutIfNeeded()
    }

    /// The entries the arrows move through are observed from the database, delivered on the main queue.
    private func waitForEntries() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
    }

    private func button(_ action: String, in controller: UIViewController) throws -> UIBarButtonItem {
        let items = (controller.navigationItem.rightBarButtonItems ?? []) + (controller.toolbarItems ?? [])
        return try XCTUnwrap(items.first { $0.action == Selector(action) })
    }

    private func trigger(_ action: String, on controller: UIViewController) throws {
        let item = try button(action, in: controller)
        XCTAssertTrue(UIApplication.shared.sendAction(Selector(action), to: item.target, from: item, for: nil))
    }

    private static func find<T: UIViewController>(_ type: T.Type, from controller: UIViewController) -> T? {
        if let match = controller as? T {
            return match
        }
        for child in controller.children {
            if let match = find(type, from: child) {
                return match
            }
        }
        return nil
    }
}
