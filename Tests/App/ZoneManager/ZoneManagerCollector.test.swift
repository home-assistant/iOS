import CoreLocation
import Foundation
import GRDB
@testable import HomeAssistant
@testable import Shared
import XCTest

class ZoneManagerCollectorTests: XCTestCase {
    private var database: DatabaseQueue!
    private var previousDatabase: (() -> DatabaseQueue)!
    private var delegate: FakeZoneManagerCollectorDelegate!
    private var locationManager: FakeCLLocationManager!
    private var collector: ZoneManagerCollectorImpl!

    enum TestError: Error {
        case anyError
    }

    override func setUpWithError() throws {
        try super.setUpWithError()

        database = try DatabaseQueue()
        try AppZoneTable().createIfNeeded(database: database)
        previousDatabase = Current.database
        Current.database = { self.database }

        locationManager = FakeCLLocationManager()
        delegate = FakeZoneManagerCollectorDelegate()
        collector = ZoneManagerCollectorImpl()
        collector.delegate = delegate
    }

    override func tearDown() {
        Current.database = previousDatabase

        super.tearDown()
    }

    func testDidFailDoesLog() {
        collector.locationManager(locationManager, didFailWithError: TestError.anyError)
        XCTAssertEqual(delegate.states.count, 1)

        guard let state = delegate.states.first else {
            return
        }

        switch state {
        case .didError(TestError.anyError):
            // pass
            break
        default:
            XCTFail("expected error, got \(state)")
        }
    }

    func testDidFailMonitoringDoesLog() {
        let region = CLCircularRegion()
        collector.locationManager(locationManager, monitoringDidFailFor: region, withError: TestError.anyError)
        XCTAssertEqual(delegate.states.count, 1)

        guard let state = delegate.states.first else {
            return
        }

        switch state {
        case .didFailMonitoring(region, TestError.anyError):
            // pass
            break
        default:
            XCTFail("expected error, got \(state)")
        }
    }

    func testDidStartMonitoringLogsButDoesntRequestState() {
        let region = CLCircularRegion()
        collector.locationManager(locationManager, didStartMonitoringFor: region)
        XCTAssertEqual(delegate.states.count, 1)

        guard let state = delegate.states.first else {
            return
        }

        switch state {
        case .didStartMonitoring(region):
            // pass
            break
        default:
            XCTFail("expected start, got \(state)")
        }

        XCTAssertEqual(locationManager.requestedRegions, [])
    }

    func testDidDetermineStateWithNoZoneInDatabase() {
        let region = CLCircularRegion()
        collector.locationManager(locationManager, didDetermineState: .inside, for: region)
        XCTAssertEqual(delegate.events.count, 1)

        guard let event = delegate.events.first else {
            return
        }

        XCTAssertEqual(event.eventType, .region(region, .inside))
        XCTAssertNil(event.associatedZone)
    }

    func testDidDetermineStateWithZoneInDatabase() throws {
        let server = Server.fake()

        let region = CLCircularRegion(
            center: .init(latitude: 1.23, longitude: 4.56),
            radius: 20,
            identifier: AppZone.primaryKey(
                sourceIdentifier: "zone_identifier",
                serverIdentifier: server.identifier.rawValue
            )
        )
        let zone = AppZone(
            entityId: "zone_identifier",
            serverIdentifier: server.identifier.rawValue
        )

        try database.write { db in
            try zone.save(db)
        }

        collector.locationManager(locationManager, didDetermineState: .inside, for: region)
        XCTAssertEqual(delegate.events.count, 1)

        guard let event = delegate.events.first else {
            return
        }

        XCTAssertEqual(event.eventType, .region(region, .inside))
        XCTAssertEqual(event.associatedZone, zone)
    }

    func testDidDetermineStateWithZoneInDatabaseForSmallRegionSplitIntoMultiple() throws {
        let server = Server.fake()
        let region = CLCircularRegion(
            center: .init(latitude: 1.23, longitude: 4.56),
            radius: 20,
            identifier: AppZone.primaryKey(
                sourceIdentifier: "zone_identifier",
                serverIdentifier: server.identifier.rawValue
            ) + "@100"
        )
        let zone = AppZone(
            entityId: "zone_identifier",
            serverIdentifier: server.identifier.rawValue
        )

        try database.write { db in
            try zone.save(db)
        }

        collector.locationManager(locationManager, didDetermineState: .inside, for: region)
        XCTAssertEqual(delegate.events.count, 1)

        guard let event = delegate.events.first else {
            return
        }

        XCTAssertEqual(event.eventType, .region(region, .inside))
        XCTAssertEqual(event.associatedZone, zone)
    }

    func testDidUpdateLocations() {
        let locations = [
            CLLocation(latitude: 1.23, longitude: 4.56),
            CLLocation(latitude: 2.34, longitude: 5.67),
        ]

        collector.locationManager(locationManager, didUpdateLocations: locations)
        XCTAssertEqual(delegate.events.count, 1)

        guard let event = delegate.events.first else {
            return
        }

        XCTAssertEqual(event.eventType, .locationChange(locations))
        XCTAssertNil(event.associatedZone)
    }

    func testIgnoredRegions() {
        let region1 = CLCircularRegion(center: .init(latitude: 1, longitude: 2), radius: 30, identifier: "1")
        let region2 = CLCircularRegion(center: .init(latitude: 2, longitude: 1), radius: 30, identifier: "2")
        collector.ignoreNextState(for: region1)
        collector.locationManager(locationManager, didDetermineState: .inside, for: region1)
        collector.locationManager(locationManager, didDetermineState: .inside, for: region2)
        XCTAssertEqual(delegate.events, [.init(eventType: .region(region2, .inside), associatedZone: nil)])
        collector.locationManager(locationManager, didDetermineState: .outside, for: region1)
        XCTAssertEqual(delegate.events, [
            .init(eventType: .region(region2, .inside), associatedZone: nil),
            .init(eventType: .region(region1, .outside), associatedZone: nil),
        ])
    }
}

private class FakeZoneManagerCollectorDelegate: ZoneManagerCollectorDelegate {
    var states = [ZoneManagerState]()
    var events = [ZoneManagerEvent]()

    func collector(_ collector: ZoneManagerCollector, didLog state: ZoneManagerState) {
        states.append(state)
    }

    func collector(_ collector: ZoneManagerCollector, didCollect event: ZoneManagerEvent) {
        events.append(event)
    }
}
