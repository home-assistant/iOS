import CoreLocation
import GRDB
@testable import HomeAssistant
import MapKit
@testable import Shared
import SharedTesting
import SwiftUI
import Testing
import UIKit

/// Drives the location history detail screen against an in-memory database: the map gets the zone,
/// region and GPS overlays, the arrows step through the history, and the toolbar actions build the
/// debug report without presenting anything (the controller is never put in a window).
///
/// `.isolatedEnvironment`: every database read (`AppZone.all()`, the history observation) happens
/// synchronously on the test's task; only the observation's results arrive on the main queue.
@Suite(.isolatedEnvironment)
@MainActor
struct LocationHistoryDetailViewControllerTests {
    private static let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeEntry(
        offset: TimeInterval,
        accuracy: CLLocationAccuracy,
        authorization: CLAccuracyAuthorization?,
        trigger: LocationUpdateTrigger = .Manual
    ) -> LocationHistoryEntry {
        let location = CLLocation(
            coordinate: .init(latitude: 52.37 + offset / 100_000, longitude: 4.89),
            altitude: 0,
            horizontalAccuracy: accuracy,
            verticalAccuracy: 0,
            timestamp: Self.baseDate
        )
        var entry = LocationHistoryEntry(
            updateType: trigger,
            location: location,
            zone: nil,
            accuracyAuthorization: .fullAccuracy,
            payload: "{\"offset\": \(offset)}"
        )
        entry.createdAt = Self.baseDate.addingTimeInterval(offset)
        entry.clAccuracyAuthorization = authorization
        return entry
    }

    /// Newest first, the order the screen observes them in.
    private func installDatabase() throws -> [LocationHistoryEntry] {
        let database = try DatabaseQueue(path: ":memory:")
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        let entries = [
            makeEntry(offset: 120, accuracy: 65, authorization: .fullAccuracy),
            makeEntry(offset: 60, accuracy: 1414, authorization: .reducedAccuracy, trigger: .RegionEnter),
            makeEntry(offset: 0, accuracy: 10, authorization: nil),
        ]
        try database.write { db in
            // A small zone is monitored as several regions, a large one as a single region.
            try AppZone(
                entityId: "zone.home",
                serverIdentifier: "server",
                friendlyName: "Home",
                latitude: 52.37,
                longitude: 4.89,
                radius: 50
            ).insert(db)
            try AppZone(
                entityId: "zone.work",
                serverIdentifier: "server",
                friendlyName: "Work",
                latitude: 52.38,
                longitude: 4.90,
                radius: 250
            ).insert(db)
            for entry in entries {
                try entry.insert(db)
            }
        }
        Current.database = { database }
        return entries
    }

    private func makeController(showing entry: LocationHistoryEntry) throws
        -> (LocationHistoryDetailViewController, MKMapView) {
        let controller = LocationHistoryDetailViewController(currentEntry: entry)
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(x: 0, y: 0, width: 390, height: 600)
        controller.view.layoutIfNeeded()
        controller.viewWillAppear(false)
        let map = try #require(controller.view.subviews.compactMap { $0 as? MKMapView }.first)
        return (controller, map)
    }

    private func title(for entry: LocationHistoryEntry) -> String {
        DateFormatter.localizedString(from: entry.createdAt, dateStyle: .short, timeStyle: .medium)
    }

    private func send(_ item: UIBarButtonItem?) {
        guard let item, let action = item.action else { return }
        UIApplication.shared.sendAction(action, to: item.target, from: item, for: nil)
    }

    @Test func showsTheEntryWithZoneRegionAndGPSOverlays() throws {
        let entries = try installDatabase()
        let (controller, map) = try makeController(showing: entries[1])

        #expect(controller.title == title(for: entries[1]))
        #expect(controller.navigationItem.title == controller.title)
        #expect(controller.navigationItem.rightBarButtonItems?.count == 2)
        #expect(controller.toolbarItems?.count == 5)

        // Two zone circles, the small zone's extra regions, and the GPS circle.
        #expect(map.overlays.count > 3)
        #expect(map.annotations.count == 1)

        for overlay in map.overlays {
            let renderer = controller.mapView(map, rendererFor: overlay)
            #expect((renderer as? MKCircleRenderer)?.fillColor != nil)
        }
        let annotation = try #require(map.annotations.first)
        let annotationView = controller.mapView(map, viewFor: annotation) as? MKMarkerAnnotationView
        #expect(annotationView?.markerTintColor == .purple)

        // Re-running the updates replaces rather than accumulates.
        let overlayCount = map.overlays.count
        controller.updateOverlays()
        controller.updateAnnotations()
        #expect(map.overlays.count == overlayCount)
        #expect(map.annotations.count == 1)
    }

    @Test func arrowsStepThroughTheHistory() async throws {
        let entries = try installDatabase()
        let (controller, _) = try makeController(showing: entries[1])
        let down = controller.navigationItem.rightBarButtonItems?.first
        let up = controller.navigationItem.rightBarButtonItems?.last

        // The history arrives asynchronously from the database observation, delivered on the main
        // queue that other suites keep busy under load; keep pressing until it has and the screen
        // moved to the oldest entry. Pressing before then does nothing.
        let reachedTheOldest = await LoadTolerantDeadline.waitUntil {
            send(down)
            return controller.title == title(for: entries[2])
        }
        #expect(reachedTheOldest)
        #expect(controller.title == title(for: entries[2]))
        #expect(down?.isEnabled == false)
        #expect(up?.isEnabled == true)

        // Past the end nothing happens.
        send(down)
        #expect(controller.title == title(for: entries[2]))

        send(up)
        send(up)
        #expect(controller.title == title(for: entries[0]))
        #expect(up?.isEnabled == false)
        #expect(down?.isEnabled == true)
        send(up)
        #expect(controller.title == title(for: entries[0]))
    }

    @Test(arguments: [0, 1, 2])
    func toolbarActionsBuildTheReportForEachAccuracy(_ index: Int) throws {
        let entries = try installDatabase()
        let (controller, _) = try makeController(showing: entries[index])

        // Center, help and share; none of them can present outside a window, but each builds its
        // content (the share sheet includes the debug report).
        for item in controller.toolbarItems ?? [] {
            send(item)
        }
        #expect(controller.presentedViewController == nil)
    }

    @Test func dismissingCallsTheCallback() throws {
        let entries = try installDatabase()
        let (controller, _) = try makeController(showing: entries[0])
        var dismissed: UIViewController?
        controller.onDismissCallback = { dismissed = $0 }

        controller.viewWillDisappear(false)

        #expect(dismissed === controller)
    }

    @Test func theSwiftUIWrapperForwardsTitleAndButtons() async throws {
        let entries = try installDatabase()
        let host = UIHostingController(rootView: NavigationView {
            LocationHistoryDetailViewControllerWrapper(currentEntry: entries[0])
        }.navigationViewStyle(.stack))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.isHidden = false
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        var detail: LocationHistoryDetailViewController?
        _ = await LoadTolerantDeadline.waitUntil {
            window.layoutIfNeeded()
            detail = Self.find(in: host)
            return detail != nil
        }
        let controller = try #require(detail)
        #expect(controller.parent?.title == title(for: entries[0]))
    }

    private static func find(in controller: UIViewController) -> LocationHistoryDetailViewController? {
        if let match = controller as? LocationHistoryDetailViewController {
            return match
        }
        for child in controller.children {
            if let match = find(in: child) {
                return match
            }
        }
        return nil
    }
}
