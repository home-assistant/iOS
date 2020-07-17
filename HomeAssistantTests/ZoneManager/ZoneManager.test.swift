import Foundation
import XCTest
import CoreLocation
@testable import HomeAssistant
import Shared
import RealmSwift
import PromiseKit

class ZoneManagerTests: XCTestCase {
    private var realm: Realm!
    private var collector: FakeCollector!
    private var processor: FakeProcessor!
    private var locationManager: FakeCLLocationManager!
    private var loggedEventsUpdatedExpectation: XCTestExpectation?
    private var loggedEvents: [ClientEvent]! {
        didSet {
            loggedEventsUpdatedExpectation?.fulfill()
        }
    }

    enum TestError: Error {
        case anyError
    }

    override func setUpWithError() throws {
        try super.setUpWithError()

        let executionIdentifier = UUID().uuidString

        realm = try Realm(configuration: .init(inMemoryIdentifier: executionIdentifier))
        loggedEvents = []
        Current.connectivity.currentWiFiSSID = { "wifi_name" }
        Current.realm = { self.realm }
        Current.clientEventStore.addEvent = { self.loggedEvents.append($0) }
        collector = FakeCollector()
        processor = FakeProcessor()
        locationManager = FakeCLLocationManager()
    }

    override func tearDown() {
        super.tearDown()

        Current.realm = Realm.live
        Current.clientEventStore.addEvent = { _ in }
    }

    private func addedZones(_ toAdd: [RLMZone]) throws -> [RLMZone] {
        return try realm.write {
            realm.add(toAdd)
            return toAdd
        }
    }

    func testStartingWithNoRegionsAddsFromRealm() throws {
        var removedRegions = [CLRegion]()
        var addedRegions = [CLRegion]()
        var zones = try addedZones([
            with(RLMZone()) {
                $0.ID = "home"
                $0.Latitude = 37.1234
                $0.Longitude = -122.4567
                $0.Radius = 50.0
                $0.TrackingEnabled = true
                $0.BeaconUUID = UUID().uuidString
                $0.BeaconMajor.value = 123
                $0.BeaconMinor.value = 456
            },
            with(RLMZone()) {
                $0.ID = "work"
                $0.Latitude =  37.2345
                $0.Longitude = -122.5678
                $0.Radius = 100
                $0.TrackingEnabled = true
            }
        ])
        var currentRegions: Set<CLRegion> {
            Set(zones.flatMap { $0.regionsForMonitoring })
        }

        let manager = ZoneManager(locationManager: locationManager, collector: collector, processor: processor)
        addedRegions.append(contentsOf: zones.flatMap { $0.regionsForMonitoring })

        XCTAssertEqual(
            locationManager.startMonitoringRegions.hackilySorted(),
            addedRegions.hackilySorted()
        )

        // mutate a zone
        try realm.write {
            removedRegions.append(contentsOf: zones[1].regionsForMonitoring)
            zones[1].Latitude += 0.02
            addedRegions.append(contentsOf: zones[1].regionsForMonitoring)
        }

        realm.refresh()

        XCTAssertEqual(locationManager.monitoredRegions, currentRegions)
        XCTAssertEqual(locationManager.stopMonitoringRegions.hackilySorted(), removedRegions.hackilySorted())
        XCTAssertEqual(locationManager.startMonitoringRegions.hackilySorted(), addedRegions.hackilySorted())

        // remove a zone
        try realm.write {
            let toRemove = zones.popLast()!
            removedRegions.append(contentsOf: toRemove.regionsForMonitoring)
            realm.delete(toRemove)
        }

        realm.refresh()

        XCTAssertEqual(locationManager.monitoredRegions, currentRegions)
        XCTAssertEqual(locationManager.stopMonitoringRegions.hackilySorted(), removedRegions.hackilySorted())
        XCTAssertEqual(locationManager.startMonitoringRegions.hackilySorted(), addedRegions.hackilySorted())

        withExtendedLifetime(manager) { /* silences unused variable */ }
    }

    func testStartingWithZoneButNoneWanted() throws {
        let startRegion = CLCircularRegion(
            center: .init(latitude: 12.456, longitude: 67.890),
            radius: 45,
            identifier: "abc"
        )
        locationManager.overrideMonitoredRegions.insert(startRegion)
        XCTAssertFalse(locationManager.monitoredRegions.isEmpty)

        let manager = ZoneManager(locationManager: locationManager, collector: collector, processor: processor)
        XCTAssertEqual(locationManager.stopMonitoringRegions, [startRegion])
        XCTAssertTrue(locationManager.monitoredRegions.isEmpty)

        realm.refresh()

        XCTAssertEqual(locationManager.stopMonitoringRegions, [startRegion])
        XCTAssertTrue(locationManager.monitoredRegions.isEmpty)

        withExtendedLifetime(manager) { /* silences unused variable */ }
    }

    func testTrackingDisabledNotMonitored() throws {
        let zones = try addedZones([
            with(RLMZone()) {
                $0.ID = "home"
                $0.Latitude = 37.1234
                $0.Longitude = -122.4567
                $0.Radius = 100
                $0.TrackingEnabled = false
            },
            with(RLMZone()) {
                $0.ID = "work"
                $0.Latitude =  37.2345
                $0.Longitude = -122.5678
                $0.Radius = 150
                $0.TrackingEnabled = true
            }
        ])

        let manager = ZoneManager(locationManager: locationManager, collector: collector, processor: processor)
        XCTAssertEqual(Set(locationManager.monitoredRegions.map { $0.identifier }), Set(["work"]))

        try realm.write {
            zones[0].TrackingEnabled = true
        }

        realm.refresh()

        XCTAssertEqual(Set(locationManager.monitoredRegions.map { $0.identifier }), Set(["work" ,"home"]))

        try realm.write {
            zones[1].TrackingEnabled = false
        }

        realm.refresh()

        XCTAssertEqual(Set(locationManager.monitoredRegions.map { $0.identifier }), Set(["home"]))

        withExtendedLifetime(manager) { /* silences unused variable */ }
    }

    func testBasicStartup() {
        let manager = ZoneManager(locationManager: locationManager, collector: collector, processor: processor)
        XCTAssertTrue(locationManager.isMonitoringSigLocChanges)
        XCTAssertTrue(locationManager.delegate === manager.collector)
        XCTAssertTrue(locationManager.delegate === collector)
        XCTAssertTrue(locationManager.allowsBackgroundLocationUpdates)
        XCTAssertFalse(locationManager.pausesLocationUpdatesAutomatically)
    }

    func testCollectorCollectsEventAndProcessorErrors() {
        let manager = ZoneManager(locationManager: locationManager, collector: collector, processor: processor)
        let region = CLCircularRegion(
            center: .init(latitude: 42.4242, longitude: 43.4343),
            radius: 456,
            identifier: "dogs"
        )
        let event = ZoneManagerEvent(eventType: .region(region, .inside), associatedZone: nil)

        let (promise, seal) = Promise<Void>.pending()
        processor.promiseToReturn = promise

        manager.collector(manager.collector, didCollect: event)
        XCTAssertEqual(processor.performEvent, event)
        XCTAssertTrue(loggedEvents.isEmpty)

        seal.reject(TestError.anyError)

        let expectation = self.expectation(description: "promise")
        loggedEventsUpdatedExpectation = expectation

        seal.fulfill(())
        wait(for: [expectation], timeout: 10)
        
        guard let loggedEvent = loggedEvents.first else {
            return
        }

        XCTAssertTrue(loggedEvent.type == .locationUpdate)
        XCTAssertTrue(loggedEvent.text.contains("Didn't update"))
        XCTAssertEqual(loggedEvent.jsonPayload?["start_ssid"] as? String, "wifi_name")
        XCTAssertEqual(loggedEvent.jsonPayload?["event"] as? String, event.description)
    }

    func testCollectorCollectsEventAndProcessorSucceeds() {
        let manager = ZoneManager(locationManager: locationManager, collector: collector, processor: processor)
        let region = CLCircularRegion(
            center: .init(latitude: 42.4242, longitude: 43.4343),
            radius: 456,
            identifier: "dogs"
        )
        let event = ZoneManagerEvent(eventType: .region(region, .inside), associatedZone: nil)

        let (promise, seal) = Promise<Void>.pending()
        processor.promiseToReturn = promise

        manager.collector(manager.collector, didCollect: event)
        XCTAssertEqual(processor.performEvent, event)
        XCTAssertTrue(loggedEvents.isEmpty)

        let expectation = self.expectation(description: "promise")
        loggedEventsUpdatedExpectation = expectation

        seal.fulfill(())
        wait(for: [expectation], timeout: 10)

        XCTAssertTrue(loggedEvents.count == 1)

        guard let loggedEvent = loggedEvents.first else {
            return
        }

        XCTAssertTrue(loggedEvent.type == .locationUpdate)
        XCTAssertTrue(loggedEvent.text.contains("Updated location"))
        XCTAssertEqual(loggedEvent.jsonPayload?["start_ssid"] as? String, "wifi_name")
        XCTAssertEqual(loggedEvent.jsonPayload?["event"] as? String, event.description)
    }
}

private extension Array where Element: CLRegion {
    func hackilySorted() -> [CLRegion] {
        sorted(by: { $0.identifier < $1.identifier })
    }
}

private class FakeCollector: NSObject, ZoneManagerCollector {
    var delegate: ZoneManagerCollectorDelegate?


}

private class FakeProcessor: ZoneManagerProcessor {
    var delegate: ZoneManagerProcessorDelegate?

    var promiseToReturn: Promise<Void>?
    var performEvent: ZoneManagerEvent?
    func perform(event: ZoneManagerEvent) -> Promise<Void> {
        performEvent = event
        return promiseToReturn!
    }
}
