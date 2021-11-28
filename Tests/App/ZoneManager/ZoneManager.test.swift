import CoreLocation
import Foundation
@testable import HomeAssistant
import PromiseKit
import RealmSwift
@testable import Shared
import XCTest

class ZoneManagerTests: XCTestCase {
    private var realm: Realm!
    private var collector: FakeCollector!
    private var processor: FakeProcessor!
    private var regionFilter: FakeRegionFilter!
    private var locationManager: FakeCLLocationManager!
    private var apis: [FakeHassAPI]!
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

        Current.settingsStore.locationSources.zone = true
        Current.settingsStore.locationSources.significantLocationChange = true

        let executionIdentifier = UUID().uuidString

        realm = try Realm(configuration: .init(inMemoryIdentifier: executionIdentifier))

        let servers = FakeServerManager(initial: 2)
        let server1 = servers.all[0]
        let server2 = servers.all[1]
        apis = [FakeHassAPI(server: server1), FakeHassAPI(server: server2)]
        Current.servers = servers
        Current.cachedApis = [server1.identifier: apis[0], server2.identifier: apis[1]]

        loggedEvents = []
        Current.connectivity.currentWiFiSSID = { "wifi_name" }
        Current.realm = { self.realm }
        Current.clientEventStore.addEvent = { self.loggedEvents.append($0); return .value(()) }
        Current.location.oneShotLocation = { _, _ in .value(.init(latitude: 0, longitude: 0)) }
        collector = FakeCollector()
        processor = FakeProcessor()
        regionFilter = FakeRegionFilter()
        locationManager = FakeCLLocationManager()
    }

    override func tearDown() {
        super.tearDown()

        Current.realm = Realm.live
        Current.clientEventStore.addEvent = { _ in .value(()) }
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
        try realm.write {
            realm.add(toAdd)
            return toAdd
        }
    }

    func testStartingWithNoRegionsAddsFromRealm() throws {
        var removedRegions = [CLRegion]()
        var addedRegions = [CLRegion]()
        var zones = try addedZones([
            with(RLMZone()) {
                $0.entityId = "home"
                $0.serverIdentifier = apis[0].server.identifier.rawValue
                $0.Latitude = 37.1234
                $0.Longitude = -122.4567
                $0.Radius = 50.0
                $0.TrackingEnabled = true
                $0.BeaconUUID = UUID().uuidString
                $0.BeaconMajor.value = 123
                $0.BeaconMinor.value = 456
            },
            with(RLMZone()) {
                $0.entityId = "work"
                $0.serverIdentifier = apis[1].server.identifier.rawValue
                $0.Latitude = 37.2345
                $0.Longitude = -122.5678
                $0.Radius = 100
                $0.TrackingEnabled = true
            },
        ])
        var currentRegions: Set<CLRegion> {
            Set(zones.flatMap(\.regionsForMonitoring))
        }

        let manager = newZoneManager()
        addedRegions.append(contentsOf: zones.flatMap(\.regionsForMonitoring))

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
        let s1: String = apis[0].server.identifier.rawValue
        let s2: String = apis[1].server.identifier.rawValue

        let zones = try addedZones([
            with(RLMZone()) {
                $0.entityId = "home"
                $0.serverIdentifier = s1
                $0.Latitude = 37.1234
                $0.Longitude = -122.4567
                $0.Radius = 100
                $0.TrackingEnabled = false
            },
            with(RLMZone()) {
                $0.entityId = "work"
                $0.serverIdentifier = s2
                $0.Latitude = 37.2345
                $0.Longitude = -122.5678
                $0.Radius = 150
                $0.TrackingEnabled = true
            },
        ])

        let manager = newZoneManager()
        XCTAssertEqual(Set(locationManager.monitoredRegions.map(\.identifier)), Set(["\(s2)/work"]))

        try realm.write {
            zones[0].TrackingEnabled = true
        }

        realm.refresh()

        XCTAssertEqual(Set(locationManager.monitoredRegions.map(\.identifier)), Set(["\(s2)/work", "\(s1)/home"]))

        try realm.write {
            zones[1].TrackingEnabled = false
        }

        realm.refresh()

        XCTAssertEqual(Set(locationManager.monitoredRegions.map(\.identifier)), Set(["\(s1)/home"]))

        withExtendedLifetime(manager) { /* silences unused variable */ }
    }

    func testFilterChangesOnLocationChange() throws {
        let zones = try addedZones([
            with(RLMZone()) {
                $0.entityId = "home"
                $0.serverIdentifier = apis[0].server.identifier.rawValue
                $0.Latitude = 37.1234
                $0.Longitude = -122.4567
                $0.Radius = 50.0
                $0.TrackingEnabled = true
                $0.BeaconUUID = UUID().uuidString
                $0.BeaconMajor.value = 123
                $0.BeaconMinor.value = 456
            },
            with(RLMZone()) {
                $0.entityId = "work"
                $0.serverIdentifier = apis[1].server.identifier.rawValue
                $0.Latitude = 37.2345
                $0.Longitude = -122.5678
                $0.Radius = 100
                $0.TrackingEnabled = true
            },
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
            AnyCollection([expectedReplacement])
        }

        processor.promiseToReturn = .value(())

        let expectation = self.expectation(description: "promise")
        expectation.assertForOverFulfill = false // changing zones adds logs and we don't care
        loggedEventsUpdatedExpectation = expectation

        manager.collector(collector, didCollect: .init(
            eventType: .locationChange([CLLocation(latitude: 1.23, longitude: 4.56)])
        ))

        let expectation2 = self.expectation(
            for: .init(format: "monitoredRegions.@count == 1"),
            evaluatedWith: locationManager,
            handler: nil
        )

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

    func testLocationUpdateSource() throws {
        let zones = try addedZones([
            with(RLMZone()) {
                $0.entityId = "home"
                $0.serverIdentifier = apis[0].server.identifier.rawValue
                $0.Latitude = 37.1234
                $0.Longitude = -122.4567
                $0.Radius = 50.0
                $0.TrackingEnabled = true
                $0.BeaconUUID = UUID().uuidString
                $0.BeaconMajor.value = 123
                $0.BeaconMinor.value = 456
            },
            with(RLMZone()) {
                $0.entityId = "work"
                $0.serverIdentifier = apis[1].server.identifier.rawValue
                $0.Latitude = 37.2345
                $0.Longitude = -122.5678
                $0.Radius = 100
                $0.TrackingEnabled = true
            },
        ])

        Current.settingsStore.locationSources.zone = false
        Current.settingsStore.locationSources.significantLocationChange = false

        let manager = newZoneManager()
        XCTAssertFalse(locationManager.isMonitoringSigLocChanges)
        XCTAssertEqual(locationManager.requestedRegions.count, 0)

        Current.settingsStore.locationSources.significantLocationChange = true
        XCTAssertTrue(locationManager.isMonitoringSigLocChanges)
        XCTAssertEqual(locationManager.requestedRegions.count, 0)

        Current.settingsStore.locationSources.zone = true
        XCTAssertTrue(locationManager.isMonitoringSigLocChanges)
        XCTAssertEqual(locationManager.startMonitoringRegions.count, zones.flatMap(\.regionsForMonitoring).count)

        withExtendedLifetime(manager) {
            // for managing the location manager
        }
    }

    func testCollectorCollectsSingleRegionZoneAndEventFires() throws {
        let manager = newZoneManager()
        let api = apis[1]
        let region = CLCircularRegion(
            center: .init(latitude: 42.4242, longitude: 43.4343),
            radius: 456,
            identifier: "dogs"
        )
        let zone = try addedZones([
            with(RLMZone()) {
                $0.entityId = "zone.zid"
                $0.serverIdentifier = api.server.identifier.rawValue
                $0.Latitude = 42.2222
                $0.Longitude = 43.3333
                $0.Radius = 100
                $0.TrackingEnabled = true
            },
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
        let api = apis[1]
        let region = CLCircularRegion(
            center: .init(latitude: 42.4242, longitude: 43.4343),
            radius: 456,
            identifier: "zone.zid@868"
        )
        let zone = try addedZones([
            with(RLMZone()) {
                $0.entityId = "zone.zid"
                $0.serverIdentifier = api.server.identifier.rawValue
                $0.Latitude = 42.2222
                $0.Longitude = 43.3333
                $0.Radius = 99
                $0.TrackingEnabled = true
            },
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

    func regions(
        from zones: AnyCollection<RLMZone>,
        currentRegions: AnyCollection<CLRegion>,
        lastLocation: CLLocation?
    ) -> AnyCollection<CLRegion> {
        lastAskedZones = zones

        if let regionsBlock = regionsBlock {
            return regionsBlock()
        } else {
            return AnyCollection(zones.flatMap(\.regionsForMonitoring))
        }
    }
}

private class FakeHassAPI: HomeAssistantAPI {
    typealias CreatedEventInfo = (eventType: String, eventData: [String: Any])

    func resetCreatedEventInfo() {
        (createdEventPromise, createdEventSeal) = Promise<CreatedEventInfo>.pending()
    }

    var createdEventPromise: Promise<CreatedEventInfo>!
    var createdEventSeal: Resolver<CreatedEventInfo>?

    override func CreateEvent(eventType: String, eventData: [String: Any]) -> Promise<Void> {
        createdEventSeal?.fulfill((eventType: eventType, eventData: eventData))
        return .value(())
    }
}
