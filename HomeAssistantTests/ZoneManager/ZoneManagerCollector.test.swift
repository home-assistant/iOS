import Foundation
import XCTest
import Shared
import CoreLocation
import RealmSwift
@testable import HomeAssistant

class ZoneManagerCollectorTests: XCTestCase {
    private var realm: Realm!
    private var delegate: FakeZoneManagerCollectorDelegate!
    private var locationManager: FakeCLLocationManager!
    private var collector: ZoneManagerCollectorImpl!

    enum TestError: Error {
        case anyError
    }

    override func setUpWithError() throws {
        try super.setUpWithError()

        let executionIdentifier = UUID().uuidString

        realm = try Realm(configuration: .init(inMemoryIdentifier: executionIdentifier))
        Current.realm = { self.realm }

        locationManager = FakeCLLocationManager()
        delegate = FakeZoneManagerCollectorDelegate()
        collector = ZoneManagerCollectorImpl()
        collector.delegate = delegate
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

    func testDidStartMonitoringLogsAndRequestsState() {
        let wasCatalyst = Current.isCatalyst
        Current.isCatalyst = false

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

        XCTAssertEqual(locationManager.requestedRegions, [region])

        Current.isCatalyst = wasCatalyst
    }

    func testDidStartMonitoringLogsButDoesntRequestsStateOnCatalyst() {
        let wasCatalyst = Current.isCatalyst
        Current.isCatalyst = true

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

        Current.isCatalyst = wasCatalyst
    }

    func testDidDetermineStateWithNoZoneInRealm() {
        let region = CLCircularRegion()
        collector.locationManager(locationManager, didDetermineState: .inside, for: region)
        XCTAssertEqual(delegate.events.count, 1)

        guard let event = delegate.events.first else {
            return
        }

        XCTAssertEqual(event.eventType, .region(region, .inside))
        XCTAssertNil(event.associatedZone)
    }

    func testDidDetermineStateWithZoneInRealm() throws {
        let region = CLCircularRegion(
            center: .init(latitude: 1.23, longitude: 4.56),
            radius: 20,
            identifier: "zone_identifier"
        )
        let realmZone = with(RLMZone()) {
            $0.ID = "zone_identifier"
        }

        try realm.write {
            realm.add(realmZone)
        }

        collector.locationManager(locationManager, didDetermineState: .inside, for: region)
        XCTAssertEqual(delegate.events.count, 1)

        guard let event = delegate.events.first else {
            return
        }

        XCTAssertEqual(event.eventType, .region(region, .inside))
        XCTAssertEqual(event.associatedZone, realmZone)
    }

    func testDidDetermineStateWithZoneInRealmForSmallRegionSplitIntoMultiple() throws {
        let region = CLCircularRegion(
            center: .init(latitude: 1.23, longitude: 4.56),
            radius: 20,
            identifier: "zone_identifier@100"
        )
        let realmZone = with(RLMZone()) {
            $0.ID = "zone_identifier"
        }

        try realm.write {
            realm.add(realmZone)
        }

        collector.locationManager(locationManager, didDetermineState: .inside, for: region)
        XCTAssertEqual(delegate.events.count, 1)

        guard let event = delegate.events.first else {
            return
        }

        XCTAssertEqual(event.eventType, .region(region, .inside))
        XCTAssertEqual(event.associatedZone, realmZone)
    }

    func testDidUpdateLocations() {
        let locations = [
            CLLocation(latitude: 1.23, longitude: 4.56),
            CLLocation(latitude: 2.34, longitude: 5.67)
        ]

        collector.locationManager(locationManager, didUpdateLocations: locations)
        XCTAssertEqual(delegate.events.count, 1)

        guard let event = delegate.events.first else {
            return
        }

        XCTAssertEqual(event.eventType, .locationChange(locations))
        XCTAssertNil(event.associatedZone)

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
