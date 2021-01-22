import Foundation
import XCTest
import CoreLocation
@testable import HomeAssistant
@testable import Shared
import RealmSwift
import PromiseKit

class ZoneManagerTests: XCTestCase {
    private var realm: Realm!
    private var collector: FakeCollector!
    private var processor: FakeProcessor!
    private var regionFilter: FakeRegionFilter!
    private var locationManager: FakeCLLocationManager!
    private var api: FakeHassAPI!
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
        api = FakeHassAPI(
            tokenInfo: TokenInfo(
                accessToken: "token",
                refreshToken: "token",
                expiration: Date()
            )
        )
        loggedEvents = []
        Current.connectivity.currentWiFiSSID = { "wifi_name" }
        Current.realm = { self.realm }
        Current.clientEventStore.addEvent = { self.loggedEvents.append($0) }
        Current.api = .value(api)
        Current.location.oneShotLocation = { _ in .value(.init(latitude: 0, longitude: 0)) }
        collector = FakeCollector()
        processor = FakeProcessor()
        regionFilter = FakeRegionFilter()
        locationManager = FakeCLLocationManager()
    }

    override func tearDown() {
        super.tearDown()

        Current.realm = Realm.live
        Current.clientEventStore.addEvent = { _ in }
        Current.resetAPI()
    }

    private func newZoneManager() -> ZoneManager {
        ZoneManager(
            locationManager: locationManager,
            collector: collector,
            processor: processor,
            regionFilter: regionFilter
        )
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

        let manager = newZoneManager()
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
        XCTAssertEqual(collector.ignoringNextStates, Set(addedRegions))

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
        XCTAssertEqual(collector.ignoringNextStates, Set(addedRegions))

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

        let manager = newZoneManager()
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

        let manager = newZoneManager()
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

    func testFilterChangesOnLocationChange() throws {
        let zones = try addedZones([
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

        XCTAssertEqual(locationManager.monitoredRegions.count, 0)

        let manager = newZoneManager()

        XCTAssertEqual(locationManager.monitoredRegions.count, 2)

        let expectedReplacement = CLCircularRegion(
            center: .init(latitude: 3.33, longitude: 4.44),
            radius: 100,
            identifier: "replaced"
        )

        regionFilter.regionsBlock = {
            return AnyCollection([ expectedReplacement ])
        }

        processor.promiseToReturn = .value(())

        let expectation = self.expectation(description: "promise")
        expectation.assertForOverFulfill = false // changing zones adds logs and we don't care
        loggedEventsUpdatedExpectation = expectation

        manager.collector(collector, didCollect: .init(
            eventType: .locationChange([CLLocation(latitude: 1.23, longitude: 4.56)])
        ))

        let expectation2 = self.expectation(for: .init(format: "monitoredRegions.@count == 1"), evaluatedWith: locationManager, handler: nil)

        wait(for: [expectation, expectation2], timeout: 10)

        XCTAssertEqual(locationManager.monitoredRegions.count, 1)
        XCTAssertEqual(locationManager.monitoredRegions, Set([expectedReplacement]))

        XCTAssertEqual(regionFilter.lastAskedZones.flatMap { Set($0) }, Set(zones))
    }

    func testBasicStartup() {
        let manager = newZoneManager()
        XCTAssertTrue(locationManager.isMonitoringSigLocChanges)
        XCTAssertTrue(locationManager.delegate === manager.collector)
        XCTAssertTrue(locationManager.delegate === collector)
        XCTAssertTrue(locationManager.allowsBackgroundLocationUpdates)
        XCTAssertFalse(locationManager.pausesLocationUpdatesAutomatically)
    }

    func testCollectorCollectsSingleRegionZoneAndEventFires() throws {
        let manager = newZoneManager()
        let region = CLCircularRegion(
            center: .init(latitude: 42.4242, longitude: 43.4343),
            radius: 456,
            identifier: "dogs"
        )
        let zone = try addedZones([
            with(RLMZone()) {
                $0.ID = "zone.zid"
                $0.Latitude = 42.2222
                $0.Longitude = 43.3333
                $0.Radius = 100
                $0.TrackingEnabled = true
            }
        ])[0]
        processor.promiseToReturn = .value(())

        api.resetCreatedEventInfo()

        manager.collector(collector, didCollect: ZoneManagerEvent(
            eventType: .region(region, .inside),
            associatedZone: zone
        ))

        let createdEvent1 = try hang(api.createdEventPromise)
        XCTAssertEqual(createdEvent1.eventType, "ios.zone_entered")
        XCTAssertEqual(createdEvent1.eventData["zone"] as? String, "zone.zid")

        api.resetCreatedEventInfo()
        manager.collector(collector, didCollect: ZoneManagerEvent(
            eventType: .region(region, .outside),
            associatedZone: zone
        ))

        let createdEvent2 = try hang(api.createdEventPromise)
        XCTAssertEqual(createdEvent2.eventType, "ios.zone_exited")
        XCTAssertEqual(createdEvent2.eventData["zone"] as? String, "zone.zid")
    }

    func testCollectorCollectsMultipleRegionZoneAndEventFires() throws {
        let manager = newZoneManager()
        let region = CLCircularRegion(
            center: .init(latitude: 42.4242, longitude: 43.4343),
            radius: 456,
            identifier: "zone.zid@868"
        )
        let zone = try addedZones([
            with(RLMZone()) {
                $0.ID = "zone.zid"
                $0.Latitude = 42.2222
                $0.Longitude = 43.3333
                $0.Radius = 99
                $0.TrackingEnabled = true
            }
        ])[0]
        processor.promiseToReturn = .value(())

        api.resetCreatedEventInfo()
        manager.collector(collector, didCollect: ZoneManagerEvent(
            eventType: .region(region, .inside),
            associatedZone: zone
        ))

        let createdEvent1 = try hang(api.createdEventPromise)
        XCTAssertEqual(createdEvent1.eventType, "ios.zone_entered")
        XCTAssertEqual(createdEvent1.eventData["zone"] as? String, "zone.zid")
        XCTAssertEqual(createdEvent1.eventData["multi_region_zone_id"] as? String, "868")

        api.resetCreatedEventInfo()
        manager.collector(collector, didCollect: ZoneManagerEvent(
            eventType: .region(region, .outside),
            associatedZone: zone
        ))
        let createdEvent2 = try hang(api.createdEventPromise)
        XCTAssertEqual(createdEvent2.eventType, "ios.zone_exited")
        XCTAssertEqual(createdEvent2.eventData["zone"] as? String, "zone.zid")
        XCTAssertEqual(createdEvent2.eventData["multi_region_zone_id"] as? String, "868")
    }

    func testCollectorCollectsEventAndProcessorErrors() {
        let manager = newZoneManager()
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
        let manager = newZoneManager()
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

    var ignoringNextStates = Set<CLRegion>()

    func ignoreNextState(for region: CLRegion) {
        ignoringNextStates.insert(region)
    }
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

private class FakeRegionFilter: ZoneManagerRegionFilter {
    var lastAskedZones: AnyCollection<RLMZone>?
    var regionsBlock: (() -> AnyCollection<CLRegion>)?

    func regions(from zones: AnyCollection<RLMZone>, currentRegions: AnyCollection<CLRegion>, lastLocation: CLLocation?) -> AnyCollection<CLRegion> {
        lastAskedZones = zones

        if let regionsBlock = regionsBlock {
            return regionsBlock()
        } else {
            return AnyCollection(zones.flatMap { $0.regionsForMonitoring })
        }
    }
}

private class FakeHassAPI: HomeAssistantAPI {
    typealias CreatedEventInfo = (eventType: String, eventData: [String : Any])

    func resetCreatedEventInfo() {
        (createdEventPromise, createdEventSeal) = Promise<CreatedEventInfo>.pending()
    }

    var createdEventPromise: Promise<CreatedEventInfo>!
    var createdEventSeal: Resolver<CreatedEventInfo>?

    override func CreateEvent(eventType: String, eventData: [String : Any]) -> Promise<Void> {
        createdEventSeal?.fulfill((eventType: eventType, eventData: eventData))
        return .value(())
    }
}
