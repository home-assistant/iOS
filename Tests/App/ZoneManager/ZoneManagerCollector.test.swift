import CoreLocation
import Foundation
@testable import HomeAssistant
import RealmSwift
@testable import Shared
import XCTest

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
        let server = Server.fake()

        let region = CLCircularRegion(
            center: .init(latitude: 1.23, longitude: 4.56),
            radius: 20,
            identifier: RLMZone.primaryKey(
                sourceIdentifier: "zone_identifier",
                serverIdentifier: server.identifier.rawValue
            )
        )
        let realmZone = with(RLMZone()) {
            $0.entityId = "zone_identifier"
            $0.serverIdentifier = server.identifier.rawValue
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
        let server = Server.fake()
        let region = CLCircularRegion(
            center: .init(latitude: 1.23, longitude: 4.56),
            radius: 20,
            identifier: RLMZone.primaryKey(
                sourceIdentifier: "zone_identifier",
                serverIdentifier: server.identifier.rawValue
            ) + "@100"
        )
        let realmZone = with(RLMZone()) {
            $0.entityId = "zone_identifier"
            $0.serverIdentifier = server.identifier.rawValue
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
