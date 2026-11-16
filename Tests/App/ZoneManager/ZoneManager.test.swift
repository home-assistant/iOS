import CoreLocation
import Foundation
import GRDB
@testable import HomeAssistant
import PromiseKit
@testable import Shared
import SharedTesting
import UIKit
import XCTest

final class MockClientEventStore: ClientEventStoreProtocol {
    let addEventAction: (ClientEvent) -> Void

    private let lock = NSLock()
    private var events: [ClientEvent] = []

    var addedEvents: [ClientEvent] {
        lock.lock()
        defer { lock.unlock() }
        return events
    }

    init(addEventAction: @escaping (ClientEvent) -> Void) {
        self.addEventAction = addEventAction
    }

    func addEvent(_ event: ClientEvent) {
        lock.lock()
        events.append(event)
        lock.unlock()
        addEventAction(event)
    }

    func getEvents() -> [ClientEvent] {
        addedEvents
    }

    func clearAllEvents() {
        lock.lock()
        events = []
        lock.unlock()
    }
}

class ZoneManagerTests: XCTestCase {
    /// Puts back the fake servers and other `Current` members this class swaps in, which would
    /// otherwise receive sensor updates for the rest of the run.
    private var currentSnapshot: CurrentSnapshot!

    private var database: DatabaseQueue!
    private var previousDatabase: (() -> DatabaseQueue)!
    private var collector: FakeCollector!
    private var processor: FakeProcessor!
    private var regionFilter: FakeRegionFilter!
    private var locationManager: FakeCLLocationManager!
    private var apis: [FakeHassAPI]!
    private let logLock = NSLock()
    private var logExpectations: [String: XCTestExpectation] = [:]
    private var expectedLogCounts: [String: Int] = [:]
    private var eventStore: MockClientEventStore!
    private var previousEventStore: ClientEventStoreProtocol!
    private var loggedEvents: [ClientEvent] { eventStore.getEvents() }

    private func expectLog(for event: ZoneManagerEvent) -> XCTestExpectation {
        let result = expectation(description: "processor final log: \(event.description)")
        logLock.lock()
        XCTAssertNil(logExpectations.updateValue(result, forKey: event.description))
        expectedLogCounts[event.description, default: 0] += 1
        logLock.unlock()
        return result
    }

    private func receiveLog(_ event: ClientEvent) {
        guard let identity = event.jsonPayloadJSONObject()["event"] as? String else { return }
        logLock.lock()
        let pending = logExpectations.removeValue(forKey: identity)
        logLock.unlock()
        pending?.fulfill()
    }

    enum TestError: Error {
        case anyError
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        currentSnapshot = CurrentSnapshot()

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

        previousEventStore = Current.clientEventStore
        Current.connectivity.currentNetworkState = { NetworkState(ssid: "wifi_name") }
        eventStore = MockClientEventStore { [weak self] event in
            self?.receiveLog(event)
        }
        Current.clientEventStore = eventStore
        Current.location.oneShotLocation = { _, _ in .value(.init(latitude: 0, longitude: 0)) }
        collector = FakeCollector()
        processor = FakeProcessor()
        regionFilter = FakeRegionFilter()
        locationManager = FakeCLLocationManager()
    }

    override func tearDown() {
        logLock.lock()
        XCTAssertTrue(logExpectations.isEmpty, "Every operation must drain its trailing log before teardown")
        logExpectations.removeAll()
        let expectedCounts = expectedLogCounts
        expectedLogCounts.removeAll()
        logLock.unlock()
        let actualCounts = loggedEvents.reduce(into: [String: Int]()) { counts, event in
            if let identity = event.jsonPayloadJSONObject()["event"] as? String {
                counts[identity, default: 0] += 1
            }
        }
        XCTAssertEqual(actualCounts, expectedCounts, "Missing, duplicate or foreign processor log")
        Current.database = previousDatabase
        Current.clientEventStore = previousEventStore

        currentSnapshot.restore()
        // XCTest keeps every test case instance for the whole run, so what the properties hold
        // would outlive the test: each API stays registered with the app's sensor container.
        apis = nil
        collector = nil
        processor = nil
        regionFilter = nil
        locationManager = nil
        super.tearDown()
    }

    private final class RepairScanExecution: BeaconScanBackgroundExecution {
        private(set) var beginCount = 0
        private(set) var endCount = 0
        private var active = false

        func begin(expirationHandler: @escaping () -> Void) {
            guard !active else { return }
            active = true
            beginCount += 1
        }

        func end() {
            guard active else { return }
            active = false
            endCount += 1
        }
    }

    func testSuccessfulBackgroundLocationDoesNotRearmExpiredUnchangedScan() throws {
        let previousBeta = Current.isTestFlight
        Current.isTestFlight = true
        defer { Current.isTestFlight = previousBeta }
        let zone = AppZone(entityId: "bounded_sync", serverIdentifier: "repair", beaconUUID: UUID().uuidString)
        _ = try addedZones([zone])
        let region = try XCTUnwrap(zone.beaconRegion)
        let lease = RepairScanExecution()
        var clock = Date(timeIntervalSince1970: 1000)
        var jobs = [(TimeInterval, DispatchWorkItem)]()
        let realCollector = ZoneManagerCollectorImpl(
            backgroundExecution: lease, now: { clock }, schedule: { jobs.append(($0, $1)) }
        )
        var onSync: (() -> Void)?
        let manager = ZoneManager(
            locationManager: locationManager, collector: realCollector, processor: processor,
            regionFilter: regionFilter, isApplicationActive: { false },
            syncExecutor: { work in
                work()
                let completion = onSync
                onSync = nil
                completion?()
            }
        )
        defer {
            realCollector.stopBackgroundBeaconMonitoring(manager: locationManager)
            realCollector.stopForegroundBeaconScanning(manager: locationManager)
        }
        XCTAssertEqual(locationManager.startedRangingConstraints, [region.beaconIdentityConstraint])
        XCTAssertEqual(jobs.count, 1)
        let timeout = try XCTUnwrap(jobs.first)
        XCTAssertEqual(timeout.0, 25)
        clock = clock.addingTimeInterval(25)
        timeout.1.perform()
        XCTAssertEqual(lease.endCount, 1)
        XCTAssertEqual(locationManager.stoppedRangingConstraints, [region.beaconIdentityConstraint])

        let synced = expectation(description: "successful location processor reached manager sync")
        let (promise, seal) = Promise<Void>.pending()
        processor.promiseToReturn = promise
        onSync = { synced.fulfill() }
        clock = clock.addingTimeInterval(6)
        let location = CLLocation(
            coordinate: .init(latitude: 1, longitude: 2), altitude: 0,
            horizontalAccuracy: 5, verticalAccuracy: 5, timestamp: clock
        )
        realCollector.locationManager(locationManager, didUpdateLocations: [location])
        XCTAssertEqual(processor.performEvent?.eventType, .locationChange([location]))
        let logged = try expectLog(for: XCTUnwrap(processor.performEvent))
        seal.fulfill(())
        wait(for: [synced, logged], timeout: 30)
        XCTAssertEqual(locationManager.startedRangingConstraints, [region.beaconIdentityConstraint])
        XCTAssertEqual(lease.beginCount, 1)
        XCTAssertEqual(jobs.count, 1)

        // A genuine lifecycle wake may still acquire a fresh bounded owner.
        manager.applicationWillResignActive()
        XCTAssertEqual(locationManager.startedRangingConstraints.count, 2)
        XCTAssertEqual(lease.beginCount, 2)
        clock = clock.addingTimeInterval(25)
        jobs[1].1.perform()
        let changedSync = expectation(description: "changed background definition reconciled")
        onSync = { changedSync.fulfill() }
        var changedZone = zone
        changedZone.beaconUUID = UUID().uuidString
        try database.write { try changedZone.save($0) }
        wait(for: [changedSync], timeout: 30)
        let changedRegion = try XCTUnwrap(changedZone.beaconRegion)
        XCTAssertEqual(locationManager.startedRangingConstraints.last, changedRegion.beaconIdentityConstraint)
        XCTAssertEqual(locationManager.startedRangingConstraints.count, 3)
        XCTAssertEqual(lease.beginCount, 3)
    }

    func testChangedBeaconRowRejectsSampleBeforeQueuedReconciliation() throws {
        try assertStaleBeaconSampleRejected { $0.beaconUUID = UUID().uuidString }
    }

    func testDisabledBeaconRowRejectsSampleBeforeQueuedReconciliation() throws {
        try assertStaleBeaconSampleRejected { $0.trackingEnabled = false }
    }

    func testNonBeaconRowRejectsSampleBeforeQueuedReconciliation() throws {
        try assertStaleBeaconSampleRejected { $0.beaconUUID = nil }
    }

    func testChangedMajorMinorRejectsSampleBeforeQueuedReconciliation() throws {
        try assertStaleBeaconSampleRejected {
            $0.beaconMajor = 2
            $0.beaconMinor = 3
        }
    }

    private func assertStaleBeaconSampleRejected(_ mutate: (inout AppZone) -> Void) throws {
        let previousBeta = Current.isTestFlight
        Current.isTestFlight = true
        defer { Current.isTestFlight = previousBeta }
        var zone = AppZone(entityId: "stale_sync", serverIdentifier: "repair", beaconUUID: UUID().uuidString)
        _ = try addedZones([zone])
        let originalZone = zone
        let oldRegion = try XCTUnwrap(zone.beaconRegion)
        let realCollector = ZoneManagerCollectorImpl(backgroundExecution: RepairScanExecution())
        var heldSyncs = [() -> Void]()
        var onQueued: (() -> Void)?
        let manager = ZoneManager(
            locationManager: locationManager, collector: realCollector, processor: processor,
            regionFilter: regionFilter, isApplicationActive: { true },
            syncExecutor: { work in
                heldSyncs.append(work)
                let completion = onQueued
                onQueued = nil
                completion?()
            }
        )
        defer { realCollector.stopForegroundBeaconScanning(manager: locationManager) }
        XCTAssertEqual(heldSyncs.count, 1)
        heldSyncs.removeFirst()()
        XCTAssertEqual(locationManager.startedRangingConstraints, [oldRegion.beaconIdentityConstraint])
        let queued = expectation(description: "changed GRDB row queued reconciliation")
        onQueued = { queued.fulfill() }
        mutate(&zone)
        try database.write { try zone.save($0) }
        wait(for: [queued], timeout: 30)
        XCTAssertFalse(heldSyncs.isEmpty)
        XCTAssertEqual(manager.zones.first?.beaconUUID, zone.trackingEnabled ? zone.beaconUUID : nil)

        // Keep the manager delegate attached: a stale event must not even reach its processor/fire path.
        let (promise, seal) = Promise<Void>.pending()
        processor.promiseToReturn = promise
        realCollector.didRange(
            samples: [.init(proximity: .near, rssi: -55)],
            satisfying: oldRegion.beaconIdentityConstraint, manager: locationManager
        )
        XCTAssertNil(processor.performEvent)

        // Restore the row without reconciling first. The stale sample must not have set an inside latch.
        let restoredQueued = expectation(description: "restored row queued")
        onQueued = { restoredQueued.fulfill() }
        try database.write { try originalZone.save($0) }
        wait(for: [restoredQueued], timeout: 30)
        realCollector.didRange(
            samples: [.init(proximity: .near, rssi: -55)],
            satisfying: oldRegion.beaconIdentityConstraint, manager: locationManager
        )
        XCTAssertEqual(processor.performEvent?.eventType, .region(oldRegion, .inside))
        let logged = try expectLog(for: XCTUnwrap(processor.performEvent))
        let processedSync = expectation(description: "accepted sample queued reconciliation")
        onQueued = { processedSync.fulfill() }
        seal.fulfill(())
        wait(for: [logged, processedSync], timeout: 30)

        // Release reconciliation using an enabled replacement B, then require its first sample too.
        zone.trackingEnabled = true
        if zone.beaconUUID == nil || zone.beaconUUID == originalZone.beaconUUID {
            zone.beaconUUID = UUID().uuidString
        }
        let replacementQueued = expectation(description: "replacement B queued")
        onQueued = { replacementQueued.fulfill() }
        try database.write { try zone.save($0) }
        wait(for: [replacementQueued], timeout: 30)
        XCTAssertEqual(manager.zones.first?.beaconUUID, zone.beaconUUID)
        while !heldSyncs.isEmpty {
            heldSyncs.removeFirst()()
        }
        let newRegion = try XCTUnwrap(zone.beaconRegion)
        let replacementSync = expectation(description: "replacement B processor queued reconciliation")
        onQueued = { replacementSync.fulfill() }
        processor.performEvent = nil
        let (replacementPromise, replacementSeal) = Promise<Void>.pending()
        processor.promiseToReturn = replacementPromise
        realCollector.didRange(
            samples: [.init(proximity: .near, rssi: -55)],
            satisfying: newRegion.beaconIdentityConstraint, manager: locationManager
        )
        XCTAssertEqual(processor.performEvent?.eventType, .region(newRegion, .inside))
        let replacementLogged = try expectLog(for: XCTUnwrap(processor.performEvent))
        replacementSeal.fulfill(())
        wait(for: [replacementLogged, replacementSync], timeout: 30)
        while !heldSyncs.isEmpty {
            heldSyncs.removeFirst()()
        }
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

    func testScanHandoffAcquiresNewOwnerBeforeReleasingOldOwner() {
        let manager = newZoneManager()
        collector.handoffCalls.removeAll()
        manager.applicationDidBecomeActive()
        XCTAssertEqual(collector.handoffCalls, ["startForeground", "stopBackground"])
        collector.handoffCalls.removeAll()
        manager.applicationWillResignActive()
        XCTAssertEqual(collector.handoffCalls, ["startBackground", "stopForeground"])
    }

    func testLifecycleHandoffsUseSynchronizedRegionsWithoutReadingLocationDaemon() {
        let region = CLBeaconRegion(uuid: UUID(), identifier: "cached-beacon")
        regionFilter.regionsBlock = { AnyCollection([region]) }
        let manager = newZoneManager()
        locationManager.monitoredRegionsReadsWereOnMainThread.removeAll()

        manager.applicationDidBecomeActive()
        XCTAssertEqual(collector.scannedRegions, [region])
        manager.applicationWillResignActive()
        XCTAssertEqual(collector.backgroundMonitoredRegions, [region])
        XCTAssertTrue(locationManager.monitoredRegionsReadsWereOnMainThread.isEmpty)
    }

    private func newZoneManager(
        syncExecutor: @escaping (@escaping () -> Void) -> Void = { $0() }
    ) -> ZoneManager {
        ZoneManager(
            locationManager: locationManager,
            collector: collector,
            processor: processor,
            regionFilter: regionFilter,
            syncExecutor: syncExecutor
        )
    }

    func testOneShotIgnoredBeaconEntryCanRetryThroughCollectorAndProcessor() throws {
        let previousTestFlight = Current.isTestFlight
        let previousSingleShotQuery = Current.isPerformingSingleShotLocationQuery
        Current.isTestFlight = true
        defer {
            Current.isTestFlight = previousTestFlight
            Current.isPerformingSingleShotLocationQuery = previousSingleShotQuery
        }
        let zone = AppZone(
            entityId: "one_shot_retry",
            serverIdentifier: apis[0].server.identifier.rawValue,
            beaconUUID: UUID().uuidString
        )
        _ = try addedZones([zone])
        let currentZone = try XCTUnwrap(AppZone.zone(identifier: zone.identifier))
        let region = try XCTUnwrap(currentZone.beaconRegion)
        let event = ZoneManagerEvent(
            eventType: .region(region, .inside),
            associatedZone: currentZone,
            beaconDiagnostic: BeaconDiagnostic(
                proximity: "near",
                rssi: -60,
                isAppActive: UIApplication.shared.applicationState == .active
            )
        )
        let realCollector = ZoneManagerCollectorImpl(backgroundExecution: RepairScanExecution())
        let realProcessor = ZoneManagerProcessorImpl()
        let manager = ZoneManager(
            locationManager: locationManager,
            collector: realCollector,
            processor: realProcessor,
            regionFilter: regionFilter,
            isApplicationActive: { true },
            syncExecutor: { $0() }
        )
        XCTAssertNotNil(manager.collector.delegate)

        Current.isPerformingSingleShotLocationQuery = true
        let firstLog = expectLog(for: event)
        realCollector.locationManager(locationManager, didDetermineState: .inside, for: region)
        realCollector.didRange(
            samples: [RangedBeaconSample(proximity: .near, rssi: -60)],
            satisfying: region.beaconIdentityConstraint,
            manager: locationManager
        )
        wait(for: [firstLog], timeout: 10)
        XCTAssertTrue(loggedEvents.last?.text.contains("ignoring during one shot") == true)
        XCTAssertFalse(try XCTUnwrap(AppZone.zone(identifier: zone.identifier)).inRegion)

        Current.isPerformingSingleShotLocationQuery = false
        let retryLog = expectLog(for: event)
        realCollector.locationManager(locationManager, didDetermineState: .inside, for: region)
        realCollector.didRange(
            samples: [RangedBeaconSample(proximity: .near, rssi: -60)],
            satisfying: region.beaconIdentityConstraint,
            manager: locationManager
        )
        wait(for: [retryLog], timeout: 10)

        XCTAssertTrue(try XCTUnwrap(AppZone.zone(identifier: zone.identifier)).inRegion)
        XCTAssertEqual(apis[0].createdEventTypes, ["ios.zone_entered"])
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
        XCTAssertEqual(collector.ignoringNextStates, Set(addedRegions))
        XCTAssertEqual(processor.resetExitReportingRegions.hackilySorted(), addedRegions.hackilySorted())

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

        let event = ZoneManagerEvent(
            eventType: .locationChange([CLLocation(latitude: 1.23, longitude: 4.56)])
        )
        let logged = expectLog(for: event)
        manager.collector(collector, didCollect: event)
        wait(for: [logged], timeout: 30)

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

        let event1 = ZoneManagerEvent(eventType: .region(region, .inside), associatedZone: zone)
        let logged1 = expectLog(for: event1)
        manager.collector(collector, didCollect: event1)

        let createdEvent1 = try hang(api.createdEventPromise)
        wait(for: [logged1], timeout: 30)
        XCTAssertEqual(createdEvent1.eventType, "ios.zone_entered")
        XCTAssertEqual(createdEvent1.eventData["zone"] as? String, "zone.zid")

        api.resetCreatedEventInfo()
        let event2 = ZoneManagerEvent(eventType: .region(region, .outside), associatedZone: zone)
        let logged2 = expectLog(for: event2)
        manager.collector(collector, didCollect: event2)

        let createdEvent2 = try hang(api.createdEventPromise)
        wait(for: [logged2], timeout: 30)
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
        let event1 = ZoneManagerEvent(eventType: .region(region, .inside), associatedZone: zone)
        let logged1 = expectLog(for: event1)
        manager.collector(collector, didCollect: event1)

        let createdEvent1 = try hang(api.createdEventPromise)
        wait(for: [logged1], timeout: 30)
        XCTAssertEqual(createdEvent1.eventType, "ios.zone_entered")
        XCTAssertEqual(createdEvent1.eventData["zone"] as? String, "zone.zid")
        XCTAssertEqual(createdEvent1.eventData["multi_region_zone_id"] as? String, "868")

        api.resetCreatedEventInfo()
        let event2 = ZoneManagerEvent(eventType: .region(region, .outside), associatedZone: zone)
        let logged2 = expectLog(for: event2)
        manager.collector(collector, didCollect: event2)
        let createdEvent2 = try hang(api.createdEventPromise)
        wait(for: [logged2], timeout: 30)
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

        let expectation = expectLog(for: event)
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

        let expectation = expectLog(for: event)

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
    var handoffCalls = [String]()

    func ignoreNextState(for region: CLRegion) {
        ignoreNextStateCallsWereOnMainThread.append(Thread.isMainThread)
        ignoringNextStates.insert(region)
    }

    func rearmBeaconEntryAfterOneShot(_ event: ZoneManagerEvent) {}

    func startForegroundBeaconScanning(in regions: Set<CLRegion>, manager: CLLocationManager) {
        handoffCalls.append("startForeground")
        foregroundScanCallsWereOnMainThread.append(Thread.isMainThread)
        scannedRegions = regions
        scanManager = manager
    }

    func stopForegroundBeaconScanning(manager: CLLocationManager) {
        handoffCalls.append("stopForeground")
        stopScanningCount += 1
        scanManager = manager
    }

    func startBackgroundBeaconMonitoring(in regions: Set<CLRegion>, manager: CLLocationManager) {
        handoffCalls.append("startBackground")
        backgroundScanCallsWereOnMainThread.append(Thread.isMainThread)
        backgroundMonitoredRegions = regions
        scanManager = manager
    }

    func stopBackgroundBeaconMonitoring(manager: CLLocationManager) {
        handoffCalls.append("stopBackground")
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

    private let lock = NSLock()
    private var pendingPromise: Promise<Void>?
    private var latestEvent: ZoneManagerEvent?

    var promiseToReturn: Promise<Void>? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return pendingPromise
        }
        set {
            lock.lock()
            pendingPromise = newValue
            lock.unlock()
        }
    }

    var performEvent: ZoneManagerEvent? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return latestEvent
        }
        set {
            lock.lock()
            latestEvent = newValue
            lock.unlock()
        }
    }

    func perform(event: ZoneManagerEvent) -> Promise<Void> {
        lock.lock()
        defer { lock.unlock() }
        latestEvent = event
        return pendingPromise!
    }

    var resetExitReportingRegions = [CLRegion]()
    func resetExitReporting(for region: CLRegion) {
        resetExitReportingRegions.append(region)
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

    func resetCreatedEventInfo() {
        (createdEventPromise, createdEventSeal) = Promise<CreatedEventInfo>.pending()
    }

    var createdEventPromise: Promise<CreatedEventInfo>!
    var createdEventSeal: Resolver<CreatedEventInfo>?
    private(set) var createdEventTypes = [String]()

    override func CreateEvent(eventType: String, eventData: [String: Any]) -> Promise<Void> {
        createdEventTypes.append(eventType)
        createdEventSeal?.fulfill((eventType: eventType, eventData: eventData))
        return .value(())
    }

    override func SubmitLocation(
        updateType: LocationUpdateTrigger,
        location: CLLocation?,
        rawLocation: CLLocation? = nil,
        zone: AppZone?
    ) -> Promise<Void> {
        .value(())
    }
}
