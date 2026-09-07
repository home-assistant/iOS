import CoreLocation
import Foundation
import GRDB
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import UserNotifications
import XCTest

final class MockClientEventStore: ClientEventStoreProtocol {
    let addEventAction: (ClientEvent) -> Void

    var addedEvents: [ClientEvent] = []

    init(addEventAction: @escaping (ClientEvent) -> Void) {
        self.addEventAction = addEventAction
    }

    func addEvent(_ event: ClientEvent) {
        addedEvents.append(event)
        addEventAction(event)
    }

    func getEvents() -> [ClientEvent] {
        addedEvents
    }

    func clearAllEvents() {
        addedEvents = []
    }
}

class ZoneManagerTests: XCTestCase {
    private final class ZoneManagerNotificationDispatcher: LocalNotificationDispatcherProtocol {
        var notifications = [LocalNotificationDispatcher.Notification]()

        func send(_ notification: LocalNotificationDispatcher.Notification) {
            notifications.append(notification)
        }

        func reschedule(_ content: UNNotificationContent, after delay: TimeInterval) {}
    }

    private final class FakeZoneEventOutbox: ZoneEventOutbox {
        private let lock = NSLock()
        private var storedEvents = [PendingZoneEvent]()
        private var deliveryClearedObserver: ((PendingZoneEvent) -> Void)?
        private var removalObserver: ((PendingZoneEvent) -> Void)?

        var events: [PendingZoneEvent] {
            get { synchronized { storedEvents } }
            set { synchronized { storedEvents = newValue } }
        }

        private func synchronized<T>(_ action: () -> T) -> T {
            lock.lock()
            defer { lock.unlock() }
            return action()
        }

        func observeDeliveryCleared(_ observer: @escaping (PendingZoneEvent) -> Void) {
            synchronized { deliveryClearedObserver = observer }
        }

        func observeRemoval(_ observer: @escaping (PendingZoneEvent) -> Void) {
            synchronized { removalObserver = observer }
        }

        func pendingEvents() throws -> [PendingZoneEvent] {
            synchronized { storedEvents }
        }

        func append(_ event: PendingZoneEvent) throws {
            synchronized { storedEvents.append(event) }
        }

        func markDeliveryStarted(id: UUID, at date: Date) throws {
            synchronized {
                guard let index = storedEvents.firstIndex(where: { $0.id == id }) else { return }
                storedEvents[index].deliveryStartedAt = date
            }
        }

        func clearDeliveryStarted(id: UUID) throws {
            let result: (PendingZoneEvent, ((PendingZoneEvent) -> Void)?)? = synchronized {
                guard let index = storedEvents.firstIndex(where: { $0.id == id }) else { return nil }
                storedEvents[index].deliveryStartedAt = nil
                return (storedEvents[index], deliveryClearedObserver)
            }
            if let (event, observer) = result {
                observer?(event)
            }
        }

        func remove(id: UUID) throws {
            let result: (PendingZoneEvent, ((PendingZoneEvent) -> Void)?)? = synchronized {
                guard let event = storedEvents.first(where: { $0.id == id }) else { return nil }
                storedEvents.removeAll { $0.id == id }
                return (event, removalObserver)
            }
            if let (event, observer) = result {
                observer?(event)
            }
        }
    }

    private final class ObservingZoneEventOutbox: ZoneEventOutbox {
        private let outbox: ZoneEventOutbox
        private let didRemove: (UUID) -> Void

        init(outbox: ZoneEventOutbox, didRemove: @escaping (UUID) -> Void) {
            self.outbox = outbox
            self.didRemove = didRemove
        }

        func pendingEvents() throws -> [PendingZoneEvent] {
            try outbox.pendingEvents()
        }

        func append(_ event: PendingZoneEvent) throws {
            try outbox.append(event)
        }

        func markDeliveryStarted(id: UUID, at date: Date) throws {
            try outbox.markDeliveryStarted(id: id, at: date)
        }

        func clearDeliveryStarted(id: UUID) throws {
            try outbox.clearDeliveryStarted(id: id)
        }

        func remove(id: UUID) throws {
            try outbox.remove(id: id)
            didRemove(id)
        }
    }

    private var database: DatabaseQueue!
    private var previousDatabase: (() -> DatabaseQueue)!
    private var collector: FakeCollector!
    private var processor: FakeProcessor!
    private var regionFilter: FakeRegionFilter!
    private var locationManager: FakeCLLocationManager!
    private var apis: [FakeHassAPI]!
    private var previousNotificationDispatcher: LocalNotificationDispatcherProtocol!
    private var notificationDispatcher: ZoneManagerNotificationDispatcher!
    private var managers = [ZoneManager]()
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

        database = try DatabaseQueue()
        try AppZoneTable().createIfNeeded(database: database)
        previousDatabase = Current.database
        Current.database = { self.database }

        let servers = FakeServerManager(initial: 2)
        let server1 = servers.all[0]
        let server2 = servers.all[1]
        apis = [FakeHassAPI(server: server1), FakeHassAPI(server: server2)]
        Current.servers = servers
        Current.cachedApis = [server1.identifier: apis[0], server2.identifier: apis[1]]

        loggedEvents = []
        Current.connectivity.currentNetworkState = { NetworkState(ssid: "wifi_name") }
        Current.clientEventStore = MockClientEventStore(addEventAction: { event in
            self.loggedEvents.append(event)
        })
        Current.location.oneShotLocation = { _, _ in .value(.init(latitude: 0, longitude: 0)) }
        previousNotificationDispatcher = Current.notificationDispatcher
        notificationDispatcher = ZoneManagerNotificationDispatcher()
        Current.notificationDispatcher = notificationDispatcher
        collector = FakeCollector()
        processor = FakeProcessor()
        regionFilter = FakeRegionFilter()
        locationManager = FakeCLLocationManager()
    }

    override func tearDown() {
        managers.removeAll()
        Current.database = previousDatabase
        Current.clientEventStore.clearAllEvents()
        Current.notificationDispatcher = previousNotificationDispatcher

        super.tearDown()
    }

    private func newZoneManager(
        syncExecutor: @escaping (@escaping () -> Void) -> Void = { $0() },
        zoneEventOutbox: ZoneEventOutbox = FakeZoneEventOutbox(),
        zoneEventRetryDelay: @escaping (Int) -> TimeInterval = { _ in 1 }
    ) -> ZoneManager {
        let manager = ZoneManager(
            locationManager: locationManager,
            collector: collector,
            processor: processor,
            regionFilter: regionFilter,
            syncExecutor: syncExecutor,
            zoneEventOutbox: zoneEventOutbox,
            zoneEventRetryDelay: zoneEventRetryDelay
        )
        managers.append(manager)
        return manager
    }

    func testBecomingActiveScansMonitoredBeaconRegions() {
        let beaconRegion = CLBeaconRegion(uuid: UUID(), identifier: "beacon")
        let circularRegion = CLCircularRegion(
            center: .init(latitude: 1, longitude: 2),
            radius: 20,
            identifier: "circular"
        )
        locationManager.overrideMonitoredRegions = [beaconRegion, circularRegion]
        regionFilter.regionsBlock = { AnyCollection([beaconRegion, circularRegion]) }

        let manager = newZoneManager()
        manager.applicationDidBecomeActive()

        XCTAssertEqual(collector.scannedRegions, locationManager.monitoredRegions)
        XCTAssertTrue(collector.scanManager === locationManager)

        manager.applicationWillResignActive()
        XCTAssertEqual(collector.stopScanningCount, 1)
        XCTAssertEqual(collector.backgroundMonitoredRegions, locationManager.monitoredRegions)
    }

    private func addedZones(_ toAdd: [AppZone]) throws -> [AppZone] {
        try database.write { db in
            for zone in toAdd {
                try zone.save(db)
            }
        }
        return toAdd
    }

    /// Waits for the zone observation (delivered asynchronously on the main
    /// queue) to propagate, until the given condition holds.
    private func waitForZoneSync(
        _ condition: @escaping () -> Bool,
        timeout: TimeInterval = 10
    ) {
        let expectation = expectation(for: NSPredicate(block: { _, _ in condition() }), evaluatedWith: nil)
        wait(for: [expectation], timeout: timeout)
    }

    func testStartingWithNoRegionsAddsFromDatabase() throws {
        var removedRegions = [CLRegion]()
        var addedRegions = [CLRegion]()
        var zones = try addedZones([
            AppZone(
                entityId: "home",
                serverIdentifier: apis[0].server.identifier.rawValue,
                latitude: 37.1234,
                longitude: -122.4567,
                radius: 50.0,
                trackingEnabled: true,
                beaconUUID: UUID().uuidString,
                beaconMajor: 123,
                beaconMinor: 456
            ),
            AppZone(
                entityId: "work",
                serverIdentifier: apis[1].server.identifier.rawValue,
                latitude: 37.2345,
                longitude: -122.5678,
                radius: 100,
                trackingEnabled: true
            ),
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
        removedRegions.append(contentsOf: zones[1].regionsForMonitoring)
        zones[1].latitude += 0.02
        addedRegions.append(contentsOf: zones[1].regionsForMonitoring)

        try database.write { [zone = zones[1]] db in
            try zone.save(db)
        }

        waitForZoneSync { [locationManager] in
            locationManager!.monitoredRegions == currentRegions
        }

        XCTAssertEqual(locationManager.monitoredRegions, currentRegions)
        XCTAssertEqual(locationManager.stopMonitoringRegions.hackilySorted(), removedRegions.hackilySorted())
        XCTAssertEqual(locationManager.startMonitoringRegions.hackilySorted(), addedRegions.hackilySorted())
        XCTAssertEqual(
            collector.ignoringNextStates,
            Set(addedRegions)
        )

        // remove a zone
        let toRemove = zones.popLast()!
        removedRegions.append(contentsOf: toRemove.regionsForMonitoring)
        _ = try database.write { db in
            try toRemove.delete(db)
        }

        waitForZoneSync { [locationManager] in
            locationManager!.monitoredRegions == currentRegions
        }

        XCTAssertEqual(locationManager.monitoredRegions, currentRegions)
        XCTAssertEqual(locationManager.stopMonitoringRegions.hackilySorted(), removedRegions.hackilySorted())
        XCTAssertEqual(locationManager.startMonitoringRegions.hackilySorted(), addedRegions.hackilySorted())
        XCTAssertEqual(
            collector.ignoringNextStates,
            Set(addedRegions)
        )

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

        withExtendedLifetime(manager) { /* silences unused variable */ }
    }

    func testTrackingDisabledNotMonitored() throws {
        let s1: String = apis[0].server.identifier.rawValue
        let s2: String = apis[1].server.identifier.rawValue

        var zones = try addedZones([
            AppZone(
                entityId: "home",
                serverIdentifier: s1,
                latitude: 37.1234,
                longitude: -122.4567,
                radius: 100,
                trackingEnabled: false
            ),
            AppZone(
                entityId: "work",
                serverIdentifier: s2,
                latitude: 37.2345,
                longitude: -122.5678,
                radius: 150,
                trackingEnabled: true
            ),
        ])

        let manager = newZoneManager()
        XCTAssertEqual(Set(locationManager.monitoredRegions.map(\.identifier)), Set(["\(s2)/work"]))

        zones[0].trackingEnabled = true
        try database.write { [zone = zones[0]] db in
            try zone.save(db)
        }

        waitForZoneSync { [locationManager] in
            Set(locationManager!.monitoredRegions.map(\.identifier)) == Set(["\(s2)/work", "\(s1)/home"])
        }

        XCTAssertEqual(Set(locationManager.monitoredRegions.map(\.identifier)), Set(["\(s2)/work", "\(s1)/home"]))

        zones[1].trackingEnabled = false
        try database.write { [zone = zones[1]] db in
            try zone.save(db)
        }

        waitForZoneSync { [locationManager] in
            Set(locationManager!.monitoredRegions.map(\.identifier)) == Set(["\(s1)/home"])
        }

        XCTAssertEqual(Set(locationManager.monitoredRegions.map(\.identifier)), Set(["\(s1)/home"]))

        withExtendedLifetime(manager) { /* silences unused variable */ }
    }

    func testFilterChangesOnLocationChange() throws {
        let zones = try addedZones([
            AppZone(
                entityId: "home",
                serverIdentifier: apis[0].server.identifier.rawValue,
                latitude: 37.1234,
                longitude: -122.4567,
                radius: 50.0,
                trackingEnabled: true,
                beaconUUID: UUID().uuidString,
                beaconMajor: 123,
                beaconMinor: 456
            ),
            AppZone(
                entityId: "work",
                serverIdentifier: apis[1].server.identifier.rawValue,
                latitude: 37.2345,
                longitude: -122.5678,
                radius: 100,
                trackingEnabled: true
            ),
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

        let expectation = expectation(description: "promise")
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

    func testSyncReadsRegionsOffMainThreadAndAppliesOnMainThread() throws {
        _ = try addedZones([
            AppZone(
                entityId: "home",
                serverIdentifier: apis[0].server.identifier.rawValue,
                latitude: 37.1234,
                longitude: -122.4567,
                radius: 100,
                trackingEnabled: true
            ),
        ])

        let syncQueue = DispatchQueue(label: "zone-manager-test-sync")
        let manager = newZoneManager(syncExecutor: { work in
            syncQueue.async(execute: work)
        })

        // poll a property only the fake writes, so the wait itself doesn't
        // record main-thread reads of monitoredRegions
        waitForZoneSync { [locationManager] in
            !locationManager!.startMonitoringRegions.isEmpty
        }

        XCTAssertFalse(locationManager.monitoredRegionsReadsWereOnMainThread.isEmpty)
        XCTAssertFalse(locationManager.monitoredRegionsReadsWereOnMainThread.contains(true))
        XCTAssertFalse(locationManager.startMonitoringCallsWereOnMainThread.isEmpty)
        XCTAssertFalse(locationManager.startMonitoringCallsWereOnMainThread.contains(false))
        XCTAssertEqual(
            collector.ignoreNextStateCallsWereOnMainThread.count,
            locationManager.startMonitoringCallsWereOnMainThread.count
        )
        XCTAssertFalse(collector.ignoreNextStateCallsWereOnMainThread.contains(false))
        XCTAssertFalse(collector.foregroundScanCallsWereOnMainThread.contains(false))
        XCTAssertFalse(collector.backgroundScanCallsWereOnMainThread.contains(false))
        XCTAssertFalse(
            collector.foregroundScanCallsWereOnMainThread.isEmpty &&
                collector.backgroundScanCallsWereOnMainThread.isEmpty
        )
        XCTAssertEqual(
            collector.scannedRegions.isEmpty ? collector.backgroundMonitoredRegions : collector.scannedRegions,
            locationManager.overrideMonitoredRegions
        )

        withExtendedLifetime(manager) { /* silences unused variable */ }
    }

    func testSyncUsesInjectedExecutor() throws {
        _ = try addedZones([
            AppZone(
                entityId: "home",
                serverIdentifier: apis[0].server.identifier.rawValue,
                latitude: 37.1234,
                longitude: -122.4567,
                radius: 100,
                trackingEnabled: true
            ),
        ])

        var executions = 0
        let manager = newZoneManager(syncExecutor: { work in
            executions += 1
            work()
        })

        XCTAssertEqual(executions, 1)
        XCTAssertFalse(locationManager.startMonitoringRegions.isEmpty)

        withExtendedLifetime(manager) { /* silences unused variable */ }
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
            AppZone(
                entityId: "home",
                serverIdentifier: apis[0].server.identifier.rawValue,
                latitude: 37.1234,
                longitude: -122.4567,
                radius: 50.0,
                trackingEnabled: true,
                beaconUUID: UUID().uuidString,
                beaconMajor: 123,
                beaconMinor: 456
            ),
            AppZone(
                entityId: "work",
                serverIdentifier: apis[1].server.identifier.rawValue,
                latitude: 37.2345,
                longitude: -122.5678,
                radius: 100,
                trackingEnabled: true
            ),
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
            AppZone(
                entityId: "zone.zid",
                serverIdentifier: api.server.identifier.rawValue,
                latitude: 42.2222,
                longitude: 43.3333,
                radius: 100,
                trackingEnabled: true
            ),
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

    func testBeaconEntryAndExitDoNotShowDiagnosticNotifications() throws {
        let manager = newZoneManager()
        let api = apis[1]
        let region = CLBeaconRegion(uuid: UUID(), identifier: "beacon-zone")
        let zone = try addedZones([
            AppZone(
                entityId: "zone.beacon",
                serverIdentifier: api.server.identifier.rawValue,
                friendlyName: "Beacon Zone",
                trackingEnabled: true,
                beaconUUID: region.uuid.uuidString
            ),
        ])[0]
        processor.promiseToReturn = .value(())

        manager.collector(collector, didCollect: ZoneManagerEvent(
            eventType: .region(region, .inside),
            associatedZone: zone
        ))

        XCTAssertFalse(notificationDispatcher.notifications.contains { $0.id == .beaconDetectedLocally })

        manager.collector(collector, didCollect: ZoneManagerEvent(
            eventType: .region(region, .outside),
            associatedZone: zone
        ))

        XCTAssertFalse(notificationDispatcher.notifications.contains { $0.id == .beaconExitedLocally })
    }

    func testSuccessfulBeaconDeliveryDoesNotShowDiagnosticNotifications() throws {
        let manager = newZoneManager()
        let api = apis[1]
        let region = CLBeaconRegion(uuid: UUID(), identifier: "beacon-zone")
        let zone = try addedZones([
            AppZone(
                entityId: "zone.beacon",
                serverIdentifier: api.server.identifier.rawValue,
                friendlyName: "Beacon Zone",
                trackingEnabled: true,
                beaconUUID: region.uuid.uuidString
            ),
        ])[0]
        processor.promiseToReturn = .value(())

        manager.collector(collector, didCollect: ZoneManagerEvent(
            eventType: .region(region, .inside),
            associatedZone: zone
        ))

        XCTAssertFalse(notificationDispatcher.notifications.contains { $0.id == .beaconEventPersisted })
        XCTAssertFalse(notificationDispatcher.notifications.contains { $0.id == .beaconEventUploadStarted })
        XCTAssertFalse(notificationDispatcher.notifications.contains { $0.id == .beaconEventDelivered })
    }

    func testFailedBeaconUploadStartQueuesWithoutDiagnosticNotification() throws {
        let outbox = FakeZoneEventOutbox()
        let manager = newZoneManager(zoneEventOutbox: outbox)
        let api = apis[1]
        let region = CLBeaconRegion(uuid: UUID(), identifier: "beacon-zone")
        let zone = try addedZones([
            AppZone(
                entityId: "zone.beacon",
                serverIdentifier: api.server.identifier.rawValue,
                friendlyName: "Beacon Zone",
                trackingEnabled: true,
                beaconUUID: region.uuid.uuidString
            ),
        ])[0]
        processor.promiseToReturn = .value(())
        api.persistentEventStartResult = .failure(TestError.anyError)

        manager.collector(collector, didCollect: ZoneManagerEvent(
            eventType: .region(region, .inside),
            associatedZone: zone
        ))

        XCTAssertEqual(outbox.events.count, 1)
        XCTAssertFalse(notificationDispatcher.notifications.contains { $0.id == .beaconEventQueued })
    }

    func testUnreadableZoneEventIsRemovedAndFollowingEventDrains() throws {
        let api = apis[1]
        let malformedID = UUID()
        let encodedMalformedEvent = try JSONSerialization.data(withJSONObject: [
            "id": malformedID.uuidString,
            "serverIdentifier": api.server.identifier.rawValue,
            "eventType": "ios.zone_entered",
            "eventData": Data("not-json".utf8).base64EncodedString(),
            "createdAt": Date().timeIntervalSinceReferenceDate,
            "isBeacon": false,
        ])
        let malformedEvent = try JSONDecoder().decode(PendingZoneEvent.self, from: encodedMalformedEvent)
        let validEvent = try PendingZoneEvent(
            serverIdentifier: api.server.identifier.rawValue,
            eventType: "ios.zone_exited",
            eventData: ["zone": "zone.zid"]
        )
        let outbox = FakeZoneEventOutbox()
        outbox.events = [malformedEvent, validEvent]
        let removed = expectation(description: "unreadable and delivered events removed")
        removed.expectedFulfillmentCount = 2
        outbox.observeRemoval { _ in removed.fulfill() }

        let manager = newZoneManager(zoneEventOutbox: outbox)

        wait(for: [removed], timeout: 1)
        XCTAssertTrue(outbox.events.isEmpty)
        XCTAssertEqual(api.createdEvents.map(\.eventType), ["ios.zone_exited"])
        XCTAssertTrue(loggedEvents.contains { $0.text.contains("Event data is unreadable") })
        withExtendedLifetime(manager) { /* retain during drain */ }
    }

    func testRejectedZoneEventRetriesAutomaticallyAndThenDrainsFollowingEvent() throws {
        let outbox = FakeZoneEventOutbox()
        let manager = newZoneManager(zoneEventOutbox: outbox, zoneEventRetryDelay: { _ in 0 })
        let api = apis[1]
        let region = CLCircularRegion(
            center: .init(latitude: 42.4242, longitude: 43.4343),
            radius: 456,
            identifier: "dogs"
        )
        let zone = try addedZones([
            AppZone(
                entityId: "zone.zid",
                serverIdentifier: api.server.identifier.rawValue,
                latitude: 42.2222,
                longitude: 43.3333,
                radius: 100,
                trackingEnabled: true
            ),
        ])[0]
        processor.promiseToReturn = .value(())
        api.enqueuePersistentEventStartResults([
            .success(.init(error: TestError.anyError)),
            .success(.value(())),
            .success(.value(())),
        ])
        let removed = expectation(description: "retried entry and following exit removed")
        removed.expectedFulfillmentCount = 2
        outbox.observeRemoval { _ in removed.fulfill() }

        manager.collector(collector, didCollect: ZoneManagerEvent(
            eventType: .region(region, .inside),
            associatedZone: zone
        ))
        manager.collector(collector, didCollect: ZoneManagerEvent(
            eventType: .region(region, .outside),
            associatedZone: zone
        ))

        wait(for: [removed], timeout: 1)
        XCTAssertTrue(outbox.events.isEmpty)
        XCTAssertEqual(
            api.createdEvents.map(\.eventType),
            ["ios.zone_entered", "ios.zone_entered", "ios.zone_exited"]
        )
        XCTAssertFalse(notificationDispatcher.notifications.contains { $0.id == .debug })
    }

    func testFailedZoneEventIsQueuedAndRetriedWhenAppBecomesActive() throws {
        let outbox = FakeZoneEventOutbox()
        let manager = newZoneManager(zoneEventOutbox: outbox, zoneEventRetryDelay: { _ in 60 })
        let api = apis[1]
        let region = CLCircularRegion(
            center: .init(latitude: 42.4242, longitude: 43.4343),
            radius: 456,
            identifier: "dogs"
        )
        let zone = try addedZones([
            AppZone(
                entityId: "zone.zid",
                serverIdentifier: api.server.identifier.rawValue,
                latitude: 42.2222,
                longitude: 43.3333,
                radius: 100,
                trackingEnabled: true
            ),
        ])[0]
        processor.promiseToReturn = .value(())
        api.persistentEventResult = .init(error: TestError.anyError)
        let deliveryFailed = expectation(description: "failed delivery becomes retryable")
        outbox.observeDeliveryCleared { _ in deliveryFailed.fulfill() }

        manager.collector(collector, didCollect: ZoneManagerEvent(
            eventType: .region(region, .inside),
            associatedZone: zone
        ))

        wait(for: [deliveryFailed], timeout: 1)
        XCTAssertEqual(api.createdEvents.count, 1)
        XCTAssertEqual(outbox.events.first?.eventType, "ios.zone_entered")

        let removed = expectation(description: "app-active retry removed delivered event")
        outbox.observeRemoval { _ in removed.fulfill() }
        api.persistentEventResult = .value(())
        manager.applicationDidBecomeActive()

        wait(for: [removed], timeout: 1)
        XCTAssertTrue(outbox.events.isEmpty)
        XCTAssertEqual(api.createdEvents.map(\.eventType), ["ios.zone_entered", "ios.zone_entered"])
    }

    func testZoneEventStartFailureRemainsImmediatelyRetryableOnNextWake() throws {
        let outbox = FakeZoneEventOutbox()
        let manager = newZoneManager(zoneEventOutbox: outbox)
        let api = apis[1]
        let region = CLCircularRegion(
            center: .init(latitude: 42.4242, longitude: 43.4343),
            radius: 456,
            identifier: "dogs"
        )
        let zone = try addedZones([
            AppZone(
                entityId: "zone.zid",
                serverIdentifier: api.server.identifier.rawValue,
                latitude: 42.2222,
                longitude: 43.3333,
                radius: 100,
                trackingEnabled: true
            ),
        ])[0]
        processor.promiseToReturn = .value(())
        api.persistentEventStartResult = .failure(TestError.anyError)

        manager.collector(collector, didCollect: ZoneManagerEvent(
            eventType: .region(region, .inside),
            associatedZone: zone
        ))

        XCTAssertEqual(outbox.events.count, 1)
        XCTAssertEqual(api.createdEvents.map(\.eventType), ["ios.zone_entered"])

        let removed = expectation(description: "next wake removed delivered event")
        outbox.observeRemoval { _ in removed.fulfill() }
        api.persistentEventStartResult = .success(.value(()))
        manager.applicationDidBecomeActive()

        wait(for: [removed], timeout: 1)
        XCTAssertTrue(outbox.events.isEmpty)
        XCTAssertEqual(api.createdEvents.map(\.eventType), ["ios.zone_entered", "ios.zone_entered"])
    }

    func testZoneEventIsPersistedBeforeBackgroundDeliveryCompletes() throws {
        let outbox = FakeZoneEventOutbox()
        let manager = newZoneManager(zoneEventOutbox: outbox)
        let api = apis[1]
        let region = CLCircularRegion(
            center: .init(latitude: 42.4242, longitude: 43.4343),
            radius: 456,
            identifier: "dogs"
        )
        let zone = try addedZones([
            AppZone(
                entityId: "zone.zid",
                serverIdentifier: api.server.identifier.rawValue,
                latitude: 42.2222,
                longitude: 43.3333,
                radius: 100,
                trackingEnabled: true
            ),
        ])[0]
        processor.promiseToReturn = .value(())
        let (delivery, deliverySeal) = Promise<Void>.pending()
        api.persistentEventResult = delivery

        manager.collector(collector, didCollect: ZoneManagerEvent(
            eventType: .region(region, .inside),
            associatedZone: zone
        ))

        XCTAssertEqual(outbox.events.count, 1)
        XCTAssertEqual(outbox.events.first?.eventType, "ios.zone_entered")

        let removed = expectation(description: "completed delivery removed persisted event")
        outbox.observeRemoval { _ in removed.fulfill() }
        deliverySeal.fulfill(())
        wait(for: [removed], timeout: 1)
        XCTAssertTrue(outbox.events.isEmpty)
    }

    func testQueuedZoneEventsRemainOrderedUntilEachDeliverySucceeds() throws {
        let outbox = FakeZoneEventOutbox()
        let manager = newZoneManager(zoneEventOutbox: outbox)
        let api = apis[1]
        let region = CLCircularRegion(
            center: .init(latitude: 42.4242, longitude: 43.4343),
            radius: 456,
            identifier: "dogs"
        )
        let zone = try addedZones([
            AppZone(
                entityId: "zone.zid",
                serverIdentifier: api.server.identifier.rawValue,
                latitude: 42.2222,
                longitude: 43.3333,
                radius: 100,
                trackingEnabled: true
            ),
        ])[0]
        processor.promiseToReturn = .value(())
        let (firstDelivery, firstDeliverySeal) = Promise<Void>.pending()
        api.persistentEventResult = firstDelivery

        manager.collector(collector, didCollect: ZoneManagerEvent(
            eventType: .region(region, .inside),
            associatedZone: zone
        ))
        manager.collector(collector, didCollect: ZoneManagerEvent(
            eventType: .region(region, .outside),
            associatedZone: zone
        ))

        XCTAssertEqual(outbox.events.map(\.eventType), ["ios.zone_entered", "ios.zone_exited"])
        XCTAssertEqual(api.createdEvents.map(\.eventType), ["ios.zone_entered"])

        let removed = expectation(description: "ordered deliveries removed")
        removed.expectedFulfillmentCount = 2
        outbox.observeRemoval { _ in removed.fulfill() }
        firstDeliverySeal.fulfill(())
        wait(for: [removed], timeout: 1)
        XCTAssertTrue(outbox.events.isEmpty)
        XCTAssertEqual(api.createdEvents.map(\.eventType), ["ios.zone_entered", "ios.zone_exited"])
    }

    func testCoalescedBeaconExitWaitsForInFlightEntry() throws {
        let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        let backingOutbox = AtomicFileZoneEventOutbox(fileURL: directoryURL.appendingPathComponent("outbox.json"))
        let removed = expectation(description: "coalesced entry and exit removed in order")
        removed.expectedFulfillmentCount = 2
        let outbox = ObservingZoneEventOutbox(outbox: backingOutbox) { _ in removed.fulfill() }
        let manager = newZoneManager(zoneEventOutbox: outbox)
        let api = apis[1]
        let region = CLBeaconRegion(uuid: UUID(), identifier: "beacon-zone")
        let zone = try addedZones([
            AppZone(
                entityId: "zone.beacon",
                serverIdentifier: api.server.identifier.rawValue,
                friendlyName: "Beacon Zone",
                trackingEnabled: true,
                beaconUUID: region.uuid.uuidString
            ),
        ])[0]
        processor.promiseToReturn = .value(())
        let (entryDelivery, entryDeliverySeal) = Promise<Void>.pending()
        api.persistentEventStartResult = .success(entryDelivery)

        manager.collector(collector, didCollect: ZoneManagerEvent(
            eventType: .region(region, .inside),
            associatedZone: zone
        ))
        manager.collector(collector, didCollect: ZoneManagerEvent(
            eventType: .region(region, .outside),
            associatedZone: zone
        ))

        XCTAssertEqual(try outbox.pendingEvents().map(\.eventType), ["ios.zone_entered", "ios.zone_exited"])
        XCTAssertEqual(api.createdEvents.map(\.eventType), ["ios.zone_entered"])

        api.persistentEventStartResult = .success(.value(()))
        entryDeliverySeal.fulfill(())
        wait(for: [removed], timeout: 1)
        XCTAssertTrue(try outbox.pendingEvents().isEmpty)
        XCTAssertEqual(api.createdEvents.map(\.eventType), ["ios.zone_entered", "ios.zone_exited"])
    }

    func testRelaunchAdoptsPersistedUploadWithoutStartingDuplicate() throws {
        let outbox = FakeZoneEventOutbox()
        let api = apis[1]
        var pending = try PendingZoneEvent(
            serverIdentifier: api.server.identifier.rawValue,
            eventType: "ios.zone_entered",
            eventData: ["zone": "zone.beacon"],
            isBeacon: true
        )
        pending.deliveryStartedAt = Date()
        outbox.events = [pending]

        let (promise, seal) = Promise<Void>.pending()
        api.persistentEventReconciliationState = .running(Task {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                promise.pipe { result in
                    switch result {
                    case .fulfilled:
                        continuation.resume()
                    case let .rejected(error):
                        continuation.resume(throwing: error)
                    }
                }
            }
        })
        let reconciled = expectation(description: "persisted upload reconciled")
        api.observePersistentEventReconciliation { _ in reconciled.fulfill() }
        let removed = expectation(description: "adopted upload removed delivered event")
        outbox.observeRemoval { _ in removed.fulfill() }

        let manager = newZoneManager(zoneEventOutbox: outbox)
        wait(for: [reconciled], timeout: 1)

        XCTAssertTrue(api.createdEvents.isEmpty)
        XCTAssertEqual(outbox.events.map(\.id), [pending.id])

        seal.fulfill(())
        wait(for: [removed], timeout: 1)
        XCTAssertTrue(outbox.events.isEmpty)
        XCTAssertTrue(api.createdEvents.isEmpty)

        withExtendedLifetime(manager) { /* retain through completion */ }
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
            AppZone(
                entityId: "zone.zid",
                serverIdentifier: api.server.identifier.rawValue,
                latitude: 42.2222,
                longitude: 43.3333,
                radius: 99,
                trackingEnabled: true
            ),
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
        XCTAssertEqual(api.ephemeralEventCount, 0)
        XCTAssertEqual(createdEvent1.eventData["multi_region_zone_id"] as? String, "868")

        api.resetCreatedEventInfo()
        manager.collector(collector, didCollect: ZoneManagerEvent(
            eventType: .region(region, .outside),
            associatedZone: zone
        ))
        let createdEvent2 = try hang(api.createdEventPromise)
        XCTAssertEqual(createdEvent2.eventType, "ios.zone_exited")
        XCTAssertEqual(createdEvent2.eventData["zone"] as? String, "zone.zid")
        XCTAssertEqual(api.ephemeralEventCount, 0)
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

        let expectation = expectation(description: "promise")
        loggedEventsUpdatedExpectation = expectation

        seal.reject(TestError.anyError)
        wait(for: [expectation], timeout: 10)

        guard let loggedEvent = loggedEvents.first else {
            return
        }

        XCTAssertTrue(loggedEvent.type == .locationUpdate)
        XCTAssertTrue(loggedEvent.text.contains("Didn't update"))
        XCTAssertEqual(loggedEvent.jsonPayloadJSONObject()["start_ssid"] as? String, "wifi_name")
        XCTAssertEqual(loggedEvent.jsonPayloadJSONObject()["event"] as? String, event.description)
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

        let expectation = expectation(description: "promise")
        loggedEventsUpdatedExpectation = expectation

        seal.fulfill(())
        wait(for: [expectation], timeout: 10)

        XCTAssertTrue(loggedEvents.count == 1)

        guard let loggedEvent = loggedEvents.first else {
            return
        }

        XCTAssertTrue(loggedEvent.type == .locationUpdate)
        XCTAssertTrue(loggedEvent.text.contains("Updated location"))
        XCTAssertEqual(loggedEvent.jsonPayloadJSONObject()["start_ssid"] as? String, "wifi_name")
        XCTAssertEqual(loggedEvent.jsonPayloadJSONObject()["event"] as? String, event.description)
    }
}

private extension Array where Element: CLRegion {
    func hackilySorted() -> [CLRegion] {
        sorted(by: { $0.identifier < $1.identifier })
    }
}

private class FakeCollector: NSObject, ZoneManagerCollector {
    weak var delegate: ZoneManagerCollectorDelegate?

    var ignoringNextStates = Set<CLRegion>()
    var ignoreNextStateCallsWereOnMainThread = [Bool]()
    var foregroundScanCallsWereOnMainThread = [Bool]()
    var backgroundScanCallsWereOnMainThread = [Bool]()
    var scannedRegions = Set<CLRegion>()
    weak var scanManager: CLLocationManager?
    var stopScanningCount = 0
    var opportunisticallyScannedRegions = Set<CLRegion>()
    var backgroundMonitoredRegions = Set<CLRegion>()
    var stopBackgroundMonitoringCount = 0

    func ignoreNextState(for region: CLRegion) {
        ignoreNextStateCallsWereOnMainThread.append(Thread.isMainThread)
        ignoringNextStates.insert(region)
    }

    func startForegroundBeaconScanning(in regions: Set<CLRegion>, manager: CLLocationManager) {
        foregroundScanCallsWereOnMainThread.append(Thread.isMainThread)
        scannedRegions = regions
        scanManager = manager
    }

    func stopForegroundBeaconScanning(manager: CLLocationManager) {
        stopScanningCount += 1
        scanManager = manager
    }

    func startBackgroundBeaconMonitoring(in regions: Set<CLRegion>, manager: CLLocationManager) {
        backgroundScanCallsWereOnMainThread.append(Thread.isMainThread)
        backgroundMonitoredRegions = regions
        scanManager = manager
    }

    func stopBackgroundBeaconMonitoring(manager: CLLocationManager) {
        stopBackgroundMonitoringCount += 1
        scanManager = manager
    }

    func startOpportunisticBeaconScanning(in regions: Set<CLRegion>, manager: CLLocationManager) {
        opportunisticallyScannedRegions = regions
        scanManager = manager
    }
}

private class FakeProcessor: ZoneManagerProcessor {
    weak var delegate: ZoneManagerProcessorDelegate?

    var promiseToReturn: Promise<Void>?
    var performEvent: ZoneManagerEvent?
    func perform(event: ZoneManagerEvent) -> Promise<Void> {
        performEvent = event
        return promiseToReturn!
    }
}

private class FakeRegionFilter: ZoneManagerRegionFilter {
    var lastAskedZones: AnyCollection<AppZone>?
    var regionsBlock: (() -> AnyCollection<CLRegion>)?

    func regions(
        from zones: AnyCollection<AppZone>,
        currentRegions: AnyCollection<CLRegion>,
        lastLocation: CLLocation?
    ) -> AnyCollection<CLRegion> {
        lastAskedZones = zones

        if let regionsBlock {
            return regionsBlock()
        } else {
            return AnyCollection(zones.flatMap(\.regionsForMonitoring))
        }
    }
}

private class FakeHassAPI: HomeAssistantAPI {
    typealias CreatedEventInfo = (eventType: String, eventData: [String: Any])

    private let lock = NSLock()
    private var storedPersistentEventResult: Promise<Void> = .value(())
    private var storedPersistentEventStartResult: Swift.Result<Promise<Void>, Error>?
    private var queuedPersistentEventStartResults = [Swift.Result<Promise<Void>, Error>]()
    private var storedPersistentEventReconciliationState: PersistedBackgroundRequestState = .absent
    private var storedCreatedEvents = [CreatedEventInfo]()
    private var storedCreatedEventIdentifiers = [UUID]()
    private var persistentEventReconciliationObserver: ((UUID) -> Void)?

    private func synchronized<T>(_ action: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return action()
    }

    func resetCreatedEventInfo() {
        (createdEventPromise, createdEventSeal) = Promise<CreatedEventInfo>.pending()
    }

    func observePersistentEventReconciliation(_ observer: @escaping (UUID) -> Void) {
        synchronized { persistentEventReconciliationObserver = observer }
    }

    func enqueuePersistentEventStartResults(_ results: [Swift.Result<Promise<Void>, Error>]) {
        synchronized { queuedPersistentEventStartResults.append(contentsOf: results) }
    }

    var createdEventPromise: Promise<CreatedEventInfo>!
    var createdEventSeal: Resolver<CreatedEventInfo>?
    var ephemeralEventCount = 0
    var persistentEventResult: Promise<Void> {
        get { synchronized { storedPersistentEventResult } }
        set { synchronized { storedPersistentEventResult = newValue } }
    }

    var persistentEventStartResult: Swift.Result<Promise<Void>, Error>? {
        get { synchronized { storedPersistentEventStartResult } }
        set { synchronized { storedPersistentEventStartResult = newValue } }
    }

    var persistentEventReconciliationState: PersistedBackgroundRequestState {
        get { synchronized { storedPersistentEventReconciliationState } }
        set { synchronized { storedPersistentEventReconciliationState = newValue } }
    }

    var createdEvents: [CreatedEventInfo] {
        synchronized { storedCreatedEvents }
    }

    var createdEventIdentifiers: [UUID] {
        synchronized { storedCreatedEventIdentifiers }
    }

    override func CreateEvent(eventType: String, eventData: [String: Any]) -> Promise<Void> {
        ephemeralEventCount += 1
        return .value(())
    }

    override func startPersistentEvent(
        eventType: String,
        eventData: [String: Any],
        eventIdentifier: UUID
    ) -> Swift.Result<Task<Void, Error>, Error> {
        let startResult: Swift.Result<Promise<Void>, Error> = synchronized {
            storedCreatedEvents.append((eventType: eventType, eventData: eventData))
            storedCreatedEventIdentifiers.append(eventIdentifier)
            if queuedPersistentEventStartResults.isEmpty {
                return storedPersistentEventStartResult ?? .success(storedPersistentEventResult)
            }
            return queuedPersistentEventStartResults.removeFirst()
        }
        createdEventSeal?.fulfill((eventType: eventType, eventData: eventData))
        switch startResult {
        case let .success(promise):
            return .success(Task {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    promise.pipe { result in
                        switch result {
                        case .fulfilled:
                            continuation.resume()
                        case let .rejected(error):
                            continuation.resume(throwing: error)
                        }
                    }
                }
            })
        case let .failure(error):
            return .failure(error)
        }
    }

    override func reconcilePersistentEvent(
        eventIdentifier: UUID
    ) async -> PersistedBackgroundRequestState {
        let (state, observer) = synchronized {
            (storedPersistentEventReconciliationState, persistentEventReconciliationObserver)
        }
        observer?(eventIdentifier)
        return state
    }
}
