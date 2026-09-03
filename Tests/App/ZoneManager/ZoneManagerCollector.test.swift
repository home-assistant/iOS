import CoreLocation
import Foundation
import GRDB
@testable import HomeAssistant
@testable import Shared
import XCTest

class ZoneManagerCollectorTests: XCTestCase {
    private final class FakeBeaconScanBackgroundExecution: BeaconScanBackgroundExecution {
        private var expirationHandler: (() -> Void)?
        private(set) var beginCount = 0
        private(set) var endCount = 0

        func begin(expirationHandler: @escaping () -> Void) {
            guard self.expirationHandler == nil else { return }
            beginCount += 1
            self.expirationHandler = expirationHandler
        }

        func end() {
            guard expirationHandler != nil else { return }
            endCount += 1
            expirationHandler = nil
        }

        func expire() {
            expirationHandler?()
            end()
        }
    }

    private var database: DatabaseQueue!
    private var previousDatabase: (() -> DatabaseQueue)!
    private var delegate: FakeZoneManagerCollectorDelegate!
    private var locationManager: FakeCLLocationManager!
    private var collector: ZoneManagerCollectorImpl!
    private var backgroundExecution: FakeBeaconScanBackgroundExecution!

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
        backgroundExecution = FakeBeaconScanBackgroundExecution()
        collector = ZoneManagerCollectorImpl(backgroundExecution: backgroundExecution)
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

    func testWhenInUseAuthorizationRequestsAlwaysAuthorization() {
        locationManager.overrideAuthorizationStatus = .authorizedWhenInUse

        collector.locationManagerDidChangeAuthorization(locationManager)

        XCTAssertEqual(locationManager.requestAlwaysAuthorizationCount, 1)
    }

    func testAlwaysAuthorizationDoesNotRequestAgain() {
        locationManager.overrideAuthorizationStatus = .authorizedAlways

        collector.locationManagerDidChangeAuthorization(locationManager)

        XCTAssertEqual(locationManager.requestAlwaysAuthorizationCount, 0)
    }

    func testRangingFailureRetriesActiveConstraintAtMostTwice() {
        let region = CLBeaconRegion(uuid: UUID(), identifier: "beacon_region")
        collector = ZoneManagerCollectorImpl(beaconRangingRetryLimit: 2, beaconRangingRetryDelay: 0)
        collector.delegate = delegate
        collector.locationManager(locationManager, didDetermineState: .inside, for: region)

        collector.locationManager(
            locationManager,
            rangingBeaconsDidFailFor: region.beaconIdentityConstraint,
            withError: TestError.anyError
        )
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        collector.locationManager(
            locationManager,
            rangingBeaconsDidFailFor: region.beaconIdentityConstraint,
            withError: TestError.anyError
        )
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        collector.locationManager(
            locationManager,
            rangingBeaconsDidFailFor: region.beaconIdentityConstraint,
            withError: TestError.anyError
        )
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))

        XCTAssertEqual(locationManager.startedRangingConstraints.count, 3)
    }

    func testRangingRetryBudgetResetsAfterFinalOwnerStops() {
        let region = CLBeaconRegion(uuid: UUID(), identifier: "beacon_region")
        collector = ZoneManagerCollectorImpl(
            beaconVerificationTimeout: 0.01,
            beaconRangingRetryLimit: 1,
            beaconRangingRetryDelay: 0
        )
        collector.delegate = delegate

        collector.locationManager(locationManager, didDetermineState: .inside, for: region)
        collector.locationManager(
            locationManager,
            rangingBeaconsDidFailFor: region.beaconIdentityConstraint,
            withError: TestError.anyError
        )
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))

        collector.locationManager(locationManager, didDetermineState: .inside, for: region)
        collector.locationManager(
            locationManager,
            rangingBeaconsDidFailFor: region.beaconIdentityConstraint,
            withError: TestError.anyError
        )
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))

        XCTAssertEqual(locationManager.startedRangingConstraints.count, 4)
    }

    func testPendingExpirationPreservesForegroundOwnerForSharedConstraint() throws {
        let region = try storedBeaconRegion(entityId: "beacon_region")
        let sample = RangedBeaconSample(proximity: .near, rssi: -55)

        collector.startForegroundBeaconScanning(in: [region], manager: locationManager)
        collector.locationManager(locationManager, didDetermineState: .inside, for: region)
        backgroundExecution.expire()

        XCTAssertTrue(locationManager.stoppedRangingConstraints.isEmpty)

        collector.didRange(
            samples: [sample],
            satisfying: region.beaconIdentityConstraint,
            manager: locationManager
        )
        XCTAssertEqual(delegate.events, [
            .init(eventType: .region(region, .inside), associatedZone: AppZone.zone(identifier: region.identifier)),
        ])
    }

    func testSharedBeaconConstraintRoutesEntryToEveryRegion() {
        let uuid = UUID()
        let first = CLBeaconRegion(uuid: uuid, identifier: "first")
        let second = CLBeaconRegion(uuid: uuid, identifier: "second")
        let beacon = RangedBeaconSample(proximity: .near, rssi: -55)

        collector.locationManager(locationManager, didDetermineState: .inside, for: first)
        collector.locationManager(locationManager, didDetermineState: .inside, for: second)
        collector.didRange(
            samples: [beacon],
            satisfying: first.beaconIdentityConstraint,
            manager: locationManager
        )

        XCTAssertEqual(Set(delegate.events.map(\.description)), Set([
            ZoneManagerEvent(eventType: .region(first, .inside)).description,
            ZoneManagerEvent(eventType: .region(second, .inside)).description,
        ]))
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

    func testBackgroundBeaconMonitoringStartsOneBoundedScanForUnchangedRegions() throws {
        let beaconRegion = try storedBeaconRegion(entityId: "beacon_region")

        collector.startBackgroundBeaconMonitoring(in: [beaconRegion], manager: locationManager)
        collector.startBackgroundBeaconMonitoring(in: [beaconRegion], manager: locationManager)

        XCTAssertEqual(locationManager.startUpdatingLocationCount, 0)
        XCTAssertEqual(locationManager.startedRangingConstraints, [beaconRegion.beaconIdentityConstraint])
        XCTAssertEqual(backgroundExecution.beginCount, 1)
    }

    func testBackgroundBeaconMonitoringReconcilesChangedRegions() throws {
        let first = try storedBeaconRegion(entityId: "first")
        let second = try storedBeaconRegion(entityId: "second")

        collector.startBackgroundBeaconMonitoring(in: [first], manager: locationManager)
        collector.startBackgroundBeaconMonitoring(in: [second], manager: locationManager)

        XCTAssertEqual(locationManager.startedRangingConstraints, [
            first.beaconIdentityConstraint,
            second.beaconIdentityConstraint,
        ])
        XCTAssertEqual(locationManager.stoppedRangingConstraints, [first.beaconIdentityConstraint])
    }

    func testBackgroundBeaconMonitoringStopsAtBoundedTimeout() throws {
        let region = try storedBeaconRegion(entityId: "beacon_region")
        collector = ZoneManagerCollectorImpl(
            opportunisticBeaconScanDuration: 0.01,
            backgroundExecution: backgroundExecution
        )
        collector.delegate = delegate

        collector.startBackgroundBeaconMonitoring(in: [region], manager: locationManager)
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))

        XCTAssertEqual(locationManager.stoppedRangingConstraints, [region.beaconIdentityConstraint])
        XCTAssertEqual(backgroundExecution.endCount, 1)
    }

    func testSameBackgroundRegionsStartNewBoundedScanAfterTimeout() throws {
        let region = try storedBeaconRegion(entityId: "beacon_region")
        collector = ZoneManagerCollectorImpl(
            opportunisticBeaconScanDuration: 0.01,
            backgroundExecution: backgroundExecution
        )
        collector.delegate = delegate

        collector.startBackgroundBeaconMonitoring(in: [region], manager: locationManager)
        RunLoop.main.run(until: Date().addingTimeInterval(0.03))
        collector.startBackgroundBeaconMonitoring(in: [region], manager: locationManager)

        XCTAssertEqual(locationManager.startedRangingConstraints, [
            region.beaconIdentityConstraint,
            region.beaconIdentityConstraint,
        ])
        XCTAssertEqual(backgroundExecution.beginCount, 2)
    }

    func testStoppingBackgroundBeaconMonitoringStopsRangingWithoutChangingLocationConfiguration() throws {
        let beaconRegion = try storedBeaconRegion(entityId: "beacon_region")
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 42
        locationManager.activityType = .fitness

        collector.startBackgroundBeaconMonitoring(in: [beaconRegion], manager: locationManager)
        collector.stopBackgroundBeaconMonitoring(manager: locationManager)

        XCTAssertEqual(locationManager.stopUpdatingLocationCount, 0)
        XCTAssertEqual(locationManager.stoppedRangingConstraints, [beaconRegion.beaconIdentityConstraint])
        XCTAssertEqual(locationManager.desiredAccuracy, kCLLocationAccuracyHundredMeters)
        XCTAssertEqual(locationManager.distanceFilter, 42)
        XCTAssertEqual(locationManager.activityType, .fitness)
    }

    private func storedBeaconRegion(entityId: String, inRegion: Bool = false) throws -> CLBeaconRegion {
        let server = Server.fake()
        let zone = AppZone(
            entityId: entityId,
            serverIdentifier: server.identifier.rawValue,
            inRegion: inRegion,
            beaconUUID: UUID().uuidString
        )
        try database.write { db in
            try zone.save(db)
        }
        return CLBeaconRegion(uuid: try XCTUnwrap(UUID(uuidString: zone.beaconUUID!)), identifier: zone.identifier)
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

    func testBeaconEntryRequiresRangingConfirmation() {
        let region = CLBeaconRegion(uuid: UUID(), identifier: "beacon_region")

        collector.locationManager(locationManager, didDetermineState: .inside, for: region)

        XCTAssertTrue(delegate.events.isEmpty)
        XCTAssertEqual(locationManager.startedRangingConstraints, [region.beaconIdentityConstraint])
    }

    func testForegroundScanStartsRangingForBeaconOutsideZone() throws {
        let server = Server.fake()
        let zone = AppZone(
            entityId: "beacon_region",
            serverIdentifier: server.identifier.rawValue,
            inRegion: false
        )
        try database.write { db in
            try zone.save(db)
        }
        let region = CLBeaconRegion(uuid: UUID(), identifier: zone.identifier)

        collector.startForegroundBeaconScanning(in: [region], manager: locationManager)

        XCTAssertEqual(locationManager.startedRangingConstraints, [region.beaconIdentityConstraint])
    }

    func testForegroundScanKeepsRangingForBeaconAlreadyInsideZone() throws {
        let server = Server.fake()
        let zone = AppZone(
            entityId: "beacon_region",
            serverIdentifier: server.identifier.rawValue,
            inRegion: true
        )
        try database.write { db in
            try zone.save(db)
        }
        let region = CLBeaconRegion(uuid: UUID(), identifier: zone.identifier)

        collector.startForegroundBeaconScanning(in: [region], manager: locationManager)

        XCTAssertEqual(locationManager.startedRangingConstraints, [region.beaconIdentityConstraint])
    }

    func testForegroundScanReconcilesChangedRegions() throws {
        let first = try storedBeaconRegion(entityId: "first")
        let second = try storedBeaconRegion(entityId: "second")

        collector.startForegroundBeaconScanning(in: [first], manager: locationManager)
        collector.startForegroundBeaconScanning(in: [second], manager: locationManager)

        XCTAssertEqual(locationManager.startedRangingConstraints, [
            first.beaconIdentityConstraint,
            second.beaconIdentityConstraint,
        ])
        XCTAssertEqual(locationManager.stoppedRangingConstraints, [first.beaconIdentityConstraint])
    }

    func testForegroundScanIgnoresCircularRegions() {
        let region = CLCircularRegion(
            center: .init(latitude: 1, longitude: 2),
            radius: 20,
            identifier: "circular"
        )

        collector.startForegroundBeaconScanning(in: [region], manager: locationManager)

        XCTAssertTrue(locationManager.startedRangingConstraints.isEmpty)
    }

    func testForegroundScanStopsWhenAppResignsActive() throws {
        let server = Server.fake()
        let zone = AppZone(
            entityId: "beacon_region",
            serverIdentifier: server.identifier.rawValue,
            inRegion: false
        )
        try database.write { db in
            try zone.save(db)
        }
        let region = CLBeaconRegion(uuid: UUID(), identifier: zone.identifier)

        collector.startForegroundBeaconScanning(in: [region], manager: locationManager)
        collector.stopForegroundBeaconScanning(manager: locationManager)

        XCTAssertEqual(locationManager.stoppedRangingConstraints, [region.beaconIdentityConstraint])
    }

    func testStoppingForegroundScanPreservesOverlappingOpportunisticScan() throws {
        let server = Server.fake()
        let zone = AppZone(
            entityId: "beacon_region",
            serverIdentifier: server.identifier.rawValue,
            inRegion: false
        )
        try database.write { db in
            try zone.save(db)
        }
        let region = CLBeaconRegion(uuid: UUID(), identifier: zone.identifier)
        let beacon = RangedBeaconSample(proximity: .near, rssi: -60)

        collector.startOpportunisticBeaconScanning(in: [region], manager: locationManager)
        collector.startForegroundBeaconScanning(in: [region], manager: locationManager)
        collector.stopForegroundBeaconScanning(manager: locationManager)

        XCTAssertTrue(locationManager.stoppedRangingConstraints.isEmpty)

        collector.didRange(
            samples: [beacon],
            satisfying: region.beaconIdentityConstraint,
            manager: locationManager
        )

        XCTAssertEqual(delegate.events, [
            .init(eventType: .region(region, .inside), associatedZone: zone),
        ])
        XCTAssertEqual(locationManager.stoppedRangingConstraints, [region.beaconIdentityConstraint])
    }

    func testStoppingForegroundScanPreservesOpportunisticScanWithSharedConstraint() throws {
        let server = Server.fake()
        let uuid = UUID()
        let foregroundZone = AppZone(
            entityId: "foreground_beacon",
            serverIdentifier: server.identifier.rawValue,
            inRegion: false,
            beaconUUID: uuid.uuidString
        )
        let opportunisticZone = AppZone(
            entityId: "opportunistic_beacon",
            serverIdentifier: server.identifier.rawValue,
            inRegion: false,
            beaconUUID: uuid.uuidString
        )
        try database.write { db in
            try foregroundZone.save(db)
            try opportunisticZone.save(db)
        }
        let foregroundRegion = CLBeaconRegion(uuid: uuid, identifier: foregroundZone.identifier)
        let opportunisticRegion = CLBeaconRegion(uuid: uuid, identifier: opportunisticZone.identifier)
        let beacon = RangedBeaconSample(proximity: .near, rssi: -60)

        collector.startOpportunisticBeaconScanning(in: [opportunisticRegion], manager: locationManager)
        collector.startForegroundBeaconScanning(in: [foregroundRegion], manager: locationManager)
        collector.stopForegroundBeaconScanning(manager: locationManager)

        XCTAssertTrue(locationManager.stoppedRangingConstraints.isEmpty)

        collector.didRange(
            samples: [beacon],
            satisfying: foregroundRegion.beaconIdentityConstraint,
            manager: locationManager
        )

        XCTAssertEqual(delegate.events, [
            .init(eventType: .region(opportunisticRegion, .inside), associatedZone: opportunisticZone),
        ])
        XCTAssertEqual(locationManager.stoppedRangingConstraints, [foregroundRegion.beaconIdentityConstraint])
    }

    func testForegroundScanCollectsEntryOnceUntilExit() throws {
        let server = Server.fake()
        let zone = AppZone(
            entityId: "beacon_region",
            serverIdentifier: server.identifier.rawValue,
            inRegion: false
        )
        try database.write { db in
            try zone.save(db)
        }
        let region = CLBeaconRegion(uuid: UUID(), identifier: zone.identifier)
        let beacon = RangedBeaconSample(proximity: .near, rssi: -60)

        collector.startForegroundBeaconScanning(in: [region], manager: locationManager)
        collector.didRange(
            samples: [beacon],
            satisfying: region.beaconIdentityConstraint,
            manager: locationManager
        )
        collector.didRange(
            samples: [beacon],
            satisfying: region.beaconIdentityConstraint,
            manager: locationManager
        )

        XCTAssertEqual(delegate.events, [
            .init(eventType: .region(region, .inside), associatedZone: zone),
        ])
        XCTAssertTrue(locationManager.stoppedRangingConstraints.isEmpty)
    }

    func testForegroundAndPendingVerificationEmitOnlyOneEntry() throws {
        let server = Server.fake()
        let zone = AppZone(
            entityId: "beacon_region",
            serverIdentifier: server.identifier.rawValue,
            inRegion: false
        )
        try database.write { db in
            try zone.save(db)
        }
        let region = CLBeaconRegion(uuid: UUID(), identifier: zone.identifier)
        let beacon = RangedBeaconSample(proximity: .near, rssi: -60)

        collector.startForegroundBeaconScanning(in: [region], manager: locationManager)
        collector.locationManager(locationManager, didDetermineState: .inside, for: region)
        collector.didRange(
            samples: [beacon],
            satisfying: region.beaconIdentityConstraint,
            manager: locationManager
        )

        XCTAssertEqual(delegate.events, [
            .init(eventType: .region(region, .inside), associatedZone: zone),
        ])
    }

    func testForegroundScanCanEnterAgainAfterExit() throws {
        let server = Server.fake()
        let zone = AppZone(
            entityId: "beacon_region",
            serverIdentifier: server.identifier.rawValue,
            inRegion: false
        )
        try database.write { db in
            try zone.save(db)
        }
        let region = CLBeaconRegion(uuid: UUID(), identifier: zone.identifier)
        let beacon = RangedBeaconSample(proximity: .near, rssi: -60)

        collector.startForegroundBeaconScanning(in: [region], manager: locationManager)
        collector.didRange(
            samples: [beacon],
            satisfying: region.beaconIdentityConstraint,
            manager: locationManager
        )
        collector.locationManager(locationManager, didDetermineState: .outside, for: region)
        collector.didRange(
            samples: [beacon],
            satisfying: region.beaconIdentityConstraint,
            manager: locationManager
        )

        XCTAssertEqual(delegate.events, [
            .init(eventType: .region(region, .inside), associatedZone: zone),
            .init(eventType: .region(region, .outside), associatedZone: zone),
            .init(eventType: .region(region, .inside), associatedZone: zone),
        ])
    }

    func testBeaconEntryIsCollectedAfterRangingConfirmation() {
        let region = CLBeaconRegion(uuid: UUID(), identifier: "beacon_region")
        let beacon = RangedBeaconSample(proximity: .near, rssi: -60)

        collector.locationManager(locationManager, didDetermineState: .inside, for: region)
        collector.didRange(
            samples: [beacon],
            satisfying: region.beaconIdentityConstraint,
            manager: locationManager
        )

        XCTAssertEqual(delegate.events, [.init(eventType: .region(region, .inside))])
        XCTAssertEqual(delegate.events.first?.beaconDiagnostic?.proximity, "near")
        XCTAssertEqual(delegate.events.first?.beaconDiagnostic?.rssi, -60)
        XCTAssertEqual(locationManager.stoppedRangingConstraints, [region.beaconIdentityConstraint])
    }

    func testBeaconEntryIgnoresUnusableRangingResult() {
        let region = CLBeaconRegion(uuid: UUID(), identifier: "beacon_region")
        let beacon = RangedBeaconSample(proximity: .unknown, rssi: 0)

        collector.locationManager(locationManager, didDetermineState: .inside, for: region)
        collector.didRange(
            samples: [beacon],
            satisfying: region.beaconIdentityConstraint,
            manager: locationManager
        )

        XCTAssertTrue(delegate.events.isEmpty)
        XCTAssertTrue(locationManager.stoppedRangingConstraints.isEmpty)
    }

    func testFarBeaconCanBecomeNearDuringExtendedVerificationWindow() {
        let region = CLBeaconRegion(uuid: UUID(), identifier: "beacon_region")
        let farBeacon = RangedBeaconSample(proximity: .far, rssi: -85)
        let nearBeacon = RangedBeaconSample(proximity: .near, rssi: -55)
        collector = ZoneManagerCollectorImpl(beaconVerificationTimeout: 0.1)
        collector.delegate = delegate

        collector.locationManager(locationManager, didDetermineState: .inside, for: region)
        collector.didRange(
            samples: [farBeacon],
            satisfying: region.beaconIdentityConstraint,
            manager: locationManager
        )
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        collector.didRange(
            samples: [nearBeacon],
            satisfying: region.beaconIdentityConstraint,
            manager: locationManager
        )

        XCTAssertEqual(delegate.events, [.init(eventType: .region(region, .inside))])
    }

    func testStrongFarBeaconCreatesEntryWithoutWaitingForNearClassification() {
        let region = CLBeaconRegion(uuid: UUID(), identifier: "beacon_region")
        let beacon = RangedBeaconSample(proximity: .far, rssi: -82)

        collector.locationManager(locationManager, didDetermineState: .inside, for: region)
        collector.didRange(
            samples: [beacon],
            satisfying: region.beaconIdentityConstraint,
            manager: locationManager
        )

        XCTAssertEqual(delegate.events, [.init(eventType: .region(region, .inside))])
        XCTAssertEqual(delegate.events.first?.beaconDiagnostic?.proximity, "far")
        XCTAssertEqual(delegate.events.first?.beaconDiagnostic?.rssi, -82)
    }

    func testBeaconEntryKeepsBackgroundExecutionUntilVerified() {
        let region = CLBeaconRegion(uuid: UUID(), identifier: "beacon_region")
        let beacon = RangedBeaconSample(proximity: .near, rssi: -55)

        collector.locationManager(locationManager, didDetermineState: .inside, for: region)

        XCTAssertEqual(backgroundExecution.beginCount, 1)
        XCTAssertEqual(backgroundExecution.endCount, 0)

        collector.didRange(
            samples: [beacon],
            satisfying: region.beaconIdentityConstraint,
            manager: locationManager
        )

        XCTAssertEqual(backgroundExecution.endCount, 1)
        XCTAssertEqual(delegate.events, [.init(eventType: .region(region, .inside))])
    }

    func testBackgroundExecutionExpirationStopsPendingRanging() {
        let region = CLBeaconRegion(uuid: UUID(), identifier: "beacon_region")

        collector.locationManager(locationManager, didDetermineState: .inside, for: region)
        backgroundExecution.expire()

        XCTAssertEqual(locationManager.stoppedRangingConstraints, [region.beaconIdentityConstraint])
        XCTAssertEqual(backgroundExecution.endCount, 1)
        XCTAssertTrue(delegate.events.isEmpty)
    }

    func testBeaconEntryIsIgnoredWhenRangingTimesOut() {
        let region = CLBeaconRegion(uuid: UUID(), identifier: "beacon_region")
        let timeoutExpectation = expectation(description: "ranging timeout")
        collector = ZoneManagerCollectorImpl(
            beaconVerificationTimeout: 0.01,
            backgroundExecution: backgroundExecution
        )
        delegate.onDidLog = { state in
            if case let .didIgnore(event, ZoneManagerIgnoreReason.beaconEntryNotVerified) = state,
               event.eventType == .region(region, .inside) {
                timeoutExpectation.fulfill()
            }
        }
        collector.delegate = delegate

        collector.locationManager(locationManager, didDetermineState: .inside, for: region)
        wait(for: [timeoutExpectation], timeout: 1)

        XCTAssertTrue(delegate.events.isEmpty)
        XCTAssertEqual(locationManager.stoppedRangingConstraints, [region.beaconIdentityConstraint])
        XCTAssertEqual(backgroundExecution.endCount, 1)
    }

    func testBeaconExitIsCollected() {
        let region = CLBeaconRegion(uuid: UUID(), identifier: "beacon_region")

        collector.locationManager(locationManager, didDetermineState: .outside, for: region)

        XCTAssertEqual(delegate.events, [.init(eventType: .region(region, .outside))])
    }

    func testBeaconExitCancelsPendingEntry() {
        let region = CLBeaconRegion(uuid: UUID(), identifier: "beacon_region")
        let beacon = RangedBeaconSample(proximity: .near, rssi: -60)

        collector.locationManager(locationManager, didDetermineState: .inside, for: region)
        collector.locationManager(locationManager, didDetermineState: .outside, for: region)
        collector.didRange(
            samples: [beacon],
            satisfying: region.beaconIdentityConstraint,
            manager: locationManager
        )

        XCTAssertEqual(delegate.events, [.init(eventType: .region(region, .outside))])
        XCTAssertEqual(locationManager.stoppedRangingConstraints, [region.beaconIdentityConstraint])
    }

    func testBeaconCanEnterAgainAfterExit() {
        let region = CLBeaconRegion(uuid: UUID(), identifier: "beacon_region")
        let beacon = RangedBeaconSample(proximity: .near, rssi: -60)

        collector.locationManager(locationManager, didDetermineState: .inside, for: region)
        collector.didRange(
            samples: [beacon],
            satisfying: region.beaconIdentityConstraint,
            manager: locationManager
        )
        collector.locationManager(locationManager, didDetermineState: .outside, for: region)
        collector.locationManager(locationManager, didDetermineState: .inside, for: region)
        collector.didRange(
            samples: [beacon],
            satisfying: region.beaconIdentityConstraint,
            manager: locationManager
        )

        XCTAssertEqual(delegate.events, [
            .init(eventType: .region(region, .inside)),
            .init(eventType: .region(region, .outside)),
            .init(eventType: .region(region, .inside)),
        ])
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

    func testLocationUpdateStartsShortBeaconScan() throws {
        let server = Server.fake()
        let zone = AppZone(
            entityId: "beacon_region",
            serverIdentifier: server.identifier.rawValue,
            inRegion: false
        )
        try database.write { db in
            try zone.save(db)
        }
        let region = CLBeaconRegion(uuid: UUID(), identifier: zone.identifier)
        locationManager.overrideMonitoredRegions = [region]

        collector.locationManager(
            locationManager,
            didUpdateLocations: [CLLocation(latitude: 1.23, longitude: 4.56)]
        )

        XCTAssertEqual(locationManager.startedRangingConstraints, [region.beaconIdentityConstraint])
    }

    func testLocationUpdateAlsoScansBeaconAlreadyInsideZone() throws {
        let server = Server.fake()
        let zone = AppZone(
            entityId: "beacon_region",
            serverIdentifier: server.identifier.rawValue,
            inRegion: true
        )
        try database.write { db in
            try zone.save(db)
        }
        let region = CLBeaconRegion(uuid: UUID(), identifier: zone.identifier)
        locationManager.overrideMonitoredRegions = [region]

        collector.locationManager(
            locationManager,
            didUpdateLocations: [CLLocation(latitude: 1.23, longitude: 4.56)]
        )

        XCTAssertEqual(locationManager.startedRangingConstraints, [region.beaconIdentityConstraint])
    }

    func testStoredInsideUsableSampleDoesNotRepeatEntry() throws {
        let server = Server.fake()
        let zone = AppZone(
            entityId: "beacon_region",
            serverIdentifier: server.identifier.rawValue,
            inRegion: true
        )
        try database.write { db in
            try zone.save(db)
        }
        let region = CLBeaconRegion(uuid: UUID(), identifier: zone.identifier)
        let beacon = RangedBeaconSample(proximity: .near, rssi: -60)

        collector.startForegroundBeaconScanning(in: [region], manager: locationManager)

        collector.didRange(
            samples: [beacon],
            satisfying: region.beaconIdentityConstraint,
            manager: locationManager
        )

        XCTAssertTrue(delegate.events.isEmpty)
        XCTAssertTrue(locationManager.stoppedRangingConstraints.isEmpty)
    }

    func testReconciliationRequiresMultipleEmptyBeaconSamplesForExit() throws {
        let server = Server.fake()
        let zone = AppZone(
            entityId: "beacon_region",
            serverIdentifier: server.identifier.rawValue,
            inRegion: true
        )
        try database.write { db in
            try zone.save(db)
        }
        let region = CLBeaconRegion(uuid: UUID(), identifier: zone.identifier)
        collector = ZoneManagerCollectorImpl(
            beaconExitReconciliationDuration: 0,
            beaconExitMinimumEmptySamples: 3
        )
        collector.delegate = delegate

        collector.startForegroundBeaconScanning(in: [region], manager: locationManager)
        let beacon = RangedBeaconSample(proximity: .near, rssi: -60)
        collector.didRange(
            samples: [beacon],
            satisfying: region.beaconIdentityConstraint,
            manager: locationManager
        )
        delegate.events.removeAll()
        collector.didRange(samples: [], satisfying: region.beaconIdentityConstraint, manager: locationManager)
        collector.didRange(samples: [], satisfying: region.beaconIdentityConstraint, manager: locationManager)

        XCTAssertTrue(delegate.events.isEmpty)

        collector.didRange(samples: [], satisfying: region.beaconIdentityConstraint, manager: locationManager)

        XCTAssertEqual(delegate.events, [
            .init(eventType: .region(region, .outside), associatedZone: zone),
        ])
    }

    func testReconciliationUsableSampleResetsEmptySampleCount() throws {
        let server = Server.fake()
        let zone = AppZone(
            entityId: "beacon_region",
            serverIdentifier: server.identifier.rawValue,
            inRegion: true
        )
        try database.write { db in
            try zone.save(db)
        }
        let region = CLBeaconRegion(uuid: UUID(), identifier: zone.identifier)
        let beacon = RangedBeaconSample(proximity: .near, rssi: -60)
        collector = ZoneManagerCollectorImpl(
            beaconExitReconciliationDuration: 0,
            beaconExitMinimumEmptySamples: 3
        )
        collector.delegate = delegate

        collector.startForegroundBeaconScanning(in: [region], manager: locationManager)
        collector.didRange(
            samples: [beacon],
            satisfying: region.beaconIdentityConstraint,
            manager: locationManager
        )
        delegate.events.removeAll()
        collector.didRange(samples: [], satisfying: region.beaconIdentityConstraint, manager: locationManager)
        collector.didRange(samples: [], satisfying: region.beaconIdentityConstraint, manager: locationManager)
        collector.didRange(
            samples: [beacon],
            satisfying: region.beaconIdentityConstraint,
            manager: locationManager
        )
        collector.didRange(samples: [], satisfying: region.beaconIdentityConstraint, manager: locationManager)

        XCTAssertTrue(delegate.events.isEmpty)
    }

    func testFarBeaconDoesNotCreateEntry() throws {
        let server = Server.fake()
        let zone = AppZone(
            entityId: "beacon_region",
            serverIdentifier: server.identifier.rawValue,
            inRegion: false
        )
        try database.write { db in
            try zone.save(db)
        }
        let region = CLBeaconRegion(uuid: UUID(), identifier: zone.identifier)
        let beacon = RangedBeaconSample(proximity: .far, rssi: -90)

        collector.startForegroundBeaconScanning(in: [region], manager: locationManager)
        collector.didRange(
            samples: [beacon],
            satisfying: region.beaconIdentityConstraint,
            manager: locationManager
        )

        XCTAssertTrue(delegate.events.isEmpty)
    }

    func testStoredInsideZoneDoesNotCreateExitWithoutCurrentEntrySample() throws {
        let server = Server.fake()
        let zone = AppZone(
            entityId: "beacon_region",
            serverIdentifier: server.identifier.rawValue,
            inRegion: true
        )
        try database.write { db in
            try zone.save(db)
        }
        let region = CLBeaconRegion(uuid: UUID(), identifier: zone.identifier)
        let beacon = RangedBeaconSample(proximity: .far, rssi: -90)
        collector = ZoneManagerCollectorImpl(
            beaconExitReconciliationDuration: 0,
            beaconExitMinimumEmptySamples: 3
        )
        collector.delegate = delegate

        collector.startForegroundBeaconScanning(in: [region], manager: locationManager)
        for _ in 0 ..< 3 {
            collector.didRange(
                samples: [beacon],
                satisfying: region.beaconIdentityConstraint,
                manager: locationManager
            )
        }

        XCTAssertTrue(delegate.events.isEmpty)
    }

    func testStoredInsideZoneAcceptsCurrentSampleWithoutDuplicateEntryThenAllowsExit() throws {
        let region = try storedBeaconRegion(entityId: "beacon_region", inRegion: true)
        let sample = RangedBeaconSample(proximity: .near, rssi: -60)
        collector = ZoneManagerCollectorImpl(
            beaconExitReconciliationDuration: 0,
            beaconExitMinimumEmptySamples: 3,
            backgroundExecution: backgroundExecution
        )
        collector.delegate = delegate

        collector.startForegroundBeaconScanning(in: [region], manager: locationManager)
        collector.didRange(
            samples: [sample],
            satisfying: region.beaconIdentityConstraint,
            manager: locationManager
        )

        XCTAssertTrue(delegate.events.isEmpty)

        for _ in 0 ..< 3 {
            collector.didRange(
                samples: [],
                satisfying: region.beaconIdentityConstraint,
                manager: locationManager
            )
        }

        XCTAssertEqual(delegate.events, [
            .init(eventType: .region(region, .outside), associatedZone: AppZone.zone(identifier: region.identifier)),
        ])
    }

    func testOpportunisticScanCollectsEntryAndStopsRanging() throws {
        let server = Server.fake()
        let zone = AppZone(
            entityId: "beacon_region",
            serverIdentifier: server.identifier.rawValue,
            inRegion: false
        )
        try database.write { db in
            try zone.save(db)
        }
        let region = CLBeaconRegion(uuid: UUID(), identifier: zone.identifier)
        let beacon = RangedBeaconSample(proximity: .near, rssi: -60)

        collector.startOpportunisticBeaconScanning(in: [region], manager: locationManager)

        XCTAssertEqual(backgroundExecution.beginCount, 1)
        XCTAssertEqual(backgroundExecution.endCount, 0)

        collector.didRange(
            samples: [beacon],
            satisfying: region.beaconIdentityConstraint,
            manager: locationManager
        )

        XCTAssertEqual(delegate.events, [
            .init(eventType: .region(region, .inside), associatedZone: zone),
        ])
        XCTAssertEqual(locationManager.stoppedRangingConstraints, [region.beaconIdentityConstraint])
        XCTAssertEqual(backgroundExecution.endCount, 1)
    }

    func testOpportunisticScanTimesOut() throws {
        let server = Server.fake()
        let zone = AppZone(
            entityId: "beacon_region",
            serverIdentifier: server.identifier.rawValue,
            inRegion: false
        )
        try database.write { db in
            try zone.save(db)
        }
        let region = CLBeaconRegion(uuid: UUID(), identifier: zone.identifier)
        let timeoutExpectation = expectation(description: "opportunistic scan timeout")
        collector = ZoneManagerCollectorImpl(opportunisticBeaconScanDuration: 0.01)
        collector.delegate = delegate

        collector.startOpportunisticBeaconScanning(in: [region], manager: locationManager)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            timeoutExpectation.fulfill()
        }
        wait(for: [timeoutExpectation], timeout: 1)

        XCTAssertEqual(locationManager.stoppedRangingConstraints, [region.beaconIdentityConstraint])
        XCTAssertTrue(delegate.events.isEmpty)
    }

    func testOpportunisticScanTimeoutReconcilesStaleInsideState() throws {
        let server = Server.fake()
        let zone = AppZone(
            entityId: "beacon_region",
            serverIdentifier: server.identifier.rawValue,
            inRegion: true
        )
        try database.write { db in
            try zone.save(db)
        }
        let region = CLBeaconRegion(uuid: UUID(), identifier: zone.identifier)
        locationManager.overrideMonitoredRegions = [region]
        collector = ZoneManagerCollectorImpl(
            opportunisticBeaconScanDuration: 0.02,
            beaconExitReconciliationDuration: 0.01,
            beaconExitMinimumEmptySamples: 3
        )
        collector.delegate = delegate

        collector.startOpportunisticBeaconScanning(in: [region], manager: locationManager)
        collector.didRange(samples: [], satisfying: region.beaconIdentityConstraint, manager: locationManager)
        collector.didRange(samples: [], satisfying: region.beaconIdentityConstraint, manager: locationManager)
        collector.didRange(samples: [], satisfying: region.beaconIdentityConstraint, manager: locationManager)
        RunLoop.main.run(until: Date().addingTimeInterval(0.04))

        XCTAssertTrue(delegate.events.isEmpty)
        XCTAssertEqual(locationManager.requestedRegions, [])
        XCTAssertEqual(locationManager.stoppedRangingConstraints, [region.beaconIdentityConstraint])
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
    var onDidLog: ((ZoneManagerState) -> Void)?
    var onDidCollect: ((ZoneManagerEvent) -> Void)?

    func collector(_ collector: ZoneManagerCollector, didLog state: ZoneManagerState) {
        states.append(state)
        onDidLog?(state)
    }

    func collector(_ collector: ZoneManagerCollector, didCollect event: ZoneManagerEvent) {
        events.append(event)
        onDidCollect?(event)
    }
}
