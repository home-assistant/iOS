import CoreLocation
import Foundation
import XCTest
import PromiseKit
import RealmSwift
@testable import Shared
@testable import HomeAssistant

class ZoneManagerProcessorTests: XCTestCase {
    private var api: FakeHassAPI!
    private var (getAndSendPromise, getAndSendSeal) = Promise<Void>.pending()
    private var (submitLocationPromise, submitLocationSeal) = Promise<Void>.pending()
    private var delegate: FakeZoneManagerProcessorDelegate!
    private var processor: ZoneManagerProcessorImpl!

    private var realm: Realm!
    private var circularRegion: CLCircularRegion!
    private var circularRegionZone: RLMZone?
    private var beaconRegion: CLBeaconRegion!
    private var beaconRegionZone: RLMZone?

    override func setUpWithError() throws {
        try super.setUpWithError()

        Current.connectivity.currentWiFiSSID = { "wifi_name" }

        let executionIdentifier = UUID().uuidString

        realm = try Realm(configuration: .init(inMemoryIdentifier: executionIdentifier))
        Current.realm = { self.realm }

        circularRegion = CLCircularRegion(
            center: .init(latitude: 9.54, longitude: 3.05),
            radius: 44,
            identifier: "circular_region"
        )
        beaconRegion = CLBeaconRegion(
            proximityUUID: UUID(),
            identifier: "beacon_region"
        )

        api = FakeHassAPI(
            connectionInfo: ConnectionInfo(
                externalURL: nil,
                internalURL: nil,
                cloudhookURL: nil,
                remoteUIURL: nil,
                webhookID: "id",
                webhookSecret: nil,
                internalSSIDs: nil
            ),
            tokenInfo: TokenInfo(
                accessToken: "token",
                refreshToken: "token",
                expiration: Date()
            )
        )
        api.getAndSendPromise = getAndSendPromise
        api.submitLocationPromise = submitLocationPromise

        Current.api = { self.api }
        delegate = FakeZoneManagerProcessorDelegate()
        processor = ZoneManagerProcessorImpl()
        processor.delegate = delegate
    }

    func setUpZones(
        circular: ((CLCircularRegion, RLMZone) -> Void)? = nil,
        beacon: ((CLBeaconRegion, RLMZone) -> Void)? = nil
    ) throws {
        try realm.write {
            circularRegionZone = RLMZone()
            circularRegionZone?.ID = circularRegion.identifier
            circular?(circularRegion, circularRegionZone!)

            beaconRegionZone = RLMZone()
            beaconRegionZone?.ID = beaconRegion.identifier
            beacon?(beaconRegion, beaconRegionZone!)

            realm.add([ circularRegionZone!, beaconRegionZone! ])
        }
    }

    func testNoAPIFails() throws {
        Current.api = { nil }
        let promise = processor.perform(event: ZoneManagerEvent(eventType: .locationChange([])))

        let expectation = self.expectation(description: "promise")
        _ = promise.catch { error in
            XCTAssertEqual(error as? ZoneManagerProcessorPerformError, ZoneManagerProcessorPerformError.noAPI)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    func testPerformingOneShotErrors() throws {
        Current.isPerformingSingleShotLocationQuery = true
        let promise = processor.perform(event: ZoneManagerEvent(eventType: .locationChange([])))
        Current.isPerformingSingleShotLocationQuery = false

        XCTAssertEqual(try hangForIgnoreReason(promise), .duringOneShot)
    }

    func testPerformingEmptyLocations() throws {
        let promise = processor.perform(event: ZoneManagerEvent(eventType: .locationChange([])))

        XCTAssertEqual(try hangForIgnoreReason(promise), .locationMissingEntries)
    }

    func testLocationTooOld() throws {
        let now = Date()
        Current.date = { now }

        let locations = [
            CLLocation(
                coordinate: .init(latitude: 123, longitude: 1.23),
                altitude: 3.45,
                horizontalAccuracy: 1.25,
                verticalAccuracy: 0.36,
                timestamp: now.addingTimeInterval(-61.0)
            ),
            CLLocation(
                coordinate: .init(latitude: 123, longitude: 1.23),
                altitude: 3.45,
                horizontalAccuracy: 1.25,
                verticalAccuracy: 0.36,
                timestamp: now.addingTimeInterval(-31.0)
            ),
        ]
        let promise = processor.perform(event: ZoneManagerEvent(eventType: .locationChange(locations)))

        XCTAssertEqual(try hangForIgnoreReason(promise), .locationUpdateTooOld)
    }

    func testPerformingZoneStateBad() throws {
        let promise = processor.perform(event: ZoneManagerEvent(eventType: .region(circularRegion, .unknown)))

        XCTAssertEqual(try hangForIgnoreReason(promise), .unknownRegionState)
    }

    func testNoAssociatedZone() throws {
        let promise = processor.perform(event: ZoneManagerEvent(eventType: .region(circularRegion, .inside)))

        XCTAssertEqual(try hangForIgnoreReason(promise), .unknownRegion)
    }

    func testTrackingDisabled() throws {
        try setUpZones(circular: { region, zone in
            zone.TrackingEnabled = false
        })
        let promise = processor.perform(event: ZoneManagerEvent(eventType: .region(circularRegion, .inside), associatedZone: circularRegionZone))
        XCTAssertEqual(try hangForIgnoreReason(promise), .zoneDisabled)
    }

    func testSSIDFiltered() throws {
        try setUpZones(circular: { region, zone in
            zone.SSIDFilter.append("wifi_name")
        })
        let promise = processor.perform(event: ZoneManagerEvent(eventType: .region(circularRegion, .inside), associatedZone: circularRegionZone))
        XCTAssertEqual(try hangForIgnoreReason(promise), .ignoredSSID("wifi_name"))
    }

    func testZoneAlreadyIn() throws {
        try setUpZones(circular: { region, zone in
            zone.inRegion = true
        })
        let promise = processor.perform(event: ZoneManagerEvent(eventType: .region(circularRegion, .inside), associatedZone: circularRegionZone))
        XCTAssertEqual(try hangForIgnoreReason(promise), .zoneStateAgrees)
    }

    func testZoneAlreadyOut() throws {
        try setUpZones(circular: { region, zone in
            zone.inRegion = false
        })
        let promise = processor.perform(event: ZoneManagerEvent(eventType: .region(circularRegion, .outside), associatedZone: circularRegionZone))
        XCTAssertEqual(try hangForIgnoreReason(promise), .zoneStateAgrees)
    }

    func testZoneUpdatedToInside() throws {
        try setUpZones(circular: { region, zone in
            zone.inRegion = false
        })
        let promise = processor.perform(event: ZoneManagerEvent(eventType: .region(circularRegion, .inside), associatedZone: circularRegionZone))

        let expectation = self.expectation(description: "promise")
        promise.ensure {
            expectation.fulfill()
        }.cauterize()

        // we don't care which this flow wants
        getAndSendSeal.fulfill(())
        submitLocationSeal.fulfill(())

        wait(for: [expectation], timeout: 10.0)

        XCTAssertTrue(circularRegionZone?.inRegion ?? false)
    }

    func testZoneUpdatedToOutside() throws {
        try setUpZones(circular: { region, zone in
            zone.inRegion = true
        })
        let promise = processor.perform(event: ZoneManagerEvent(eventType: .region(circularRegion, .outside), associatedZone: circularRegionZone))

        let expectation = self.expectation(description: "promise")
        promise.ensure {
            expectation.fulfill()
        }.cauterize()

        // we don't care which this flow wants
        getAndSendSeal.fulfill(())
        submitLocationSeal.fulfill(())

        wait(for: [expectation], timeout: 10.0)

        XCTAssertFalse(circularRegionZone?.inRegion ?? true)
    }

    func testBeaconExitIgnored() throws {
        try setUpZones(beacon: { region, zone in
            zone.inRegion = true
        })
        let promise = processor.perform(event: ZoneManagerEvent(eventType: .region(beaconRegion, .outside), associatedZone: beaconRegionZone))

        let expectation = self.expectation(description: "promise")
        promise.ensure {
            expectation.fulfill()
        }.cauterize()

        wait(for: [expectation], timeout: 10.0)

        XCTAssertEqual(try hangForIgnoreReason(promise), .beaconExitIgnored)

        // it should still update the zone
        XCTAssertFalse(circularRegionZone?.inRegion ?? true)
    }

    func testOneShot() throws {
        try setUpZones(circular: { region, zone in
            zone.inRegion = true
        })
        let event = ZoneManagerEvent(
            eventType: .region(circularRegion, .outside),
            associatedZone: circularRegionZone
        )
        let promise = processor.perform(event: event)

        let expectation = self.expectation(description: "promise")
        promise.ensure {
            expectation.fulfill()
        }.cauterize()

        getAndSendSeal.fulfill(())

        wait(for: [expectation], timeout: 10.0)

        XCTAssertFalse(circularRegionZone?.inRegion ?? true)

        XCTAssertEqual(api.getAndSendInvocation?.trigger, event.asTrigger())
        XCTAssertEqual(api.getAndSendInvocation?.zone, circularRegionZone)

        if let state = delegate.states.first {
            switch state {
            case .didReceive(event):
                // pass
                break
            default:
                XCTFail("incorrect state was logged")
            }
        } else {
            XCTFail("no state but one was expected")
        }
    }

    func testNotOneShot() throws {
        try setUpZones(beacon: { region, zone in
            zone.inRegion = false
        })
        let event = ZoneManagerEvent(
            eventType: .region(beaconRegion, .inside),
            associatedZone: beaconRegionZone
        )
        let promise = processor.perform(event: event)

        let expectation = self.expectation(description: "promise")
        promise.ensure {
            expectation.fulfill()
        }.cauterize()

        submitLocationSeal.fulfill(())

        wait(for: [expectation], timeout: 10.0)

        XCTAssertFalse(circularRegionZone?.inRegion ?? true)

        XCTAssertEqual(api.submitLocationInvocation?.updateType, event.asTrigger())
        XCTAssertEqual(api.submitLocationInvocation?.location, event.associatedLocation)
        XCTAssertEqual(api.submitLocationInvocation?.zone, beaconRegionZone)

        if let state = delegate.states.first {
            switch state {
            case .didReceive(event):
                // pass
                break
            default:
                XCTFail("incorrect state was logged")
            }
        } else {
            XCTFail("no state but one was expected")
        }
    }

    // MARK: -
    private func hangForIgnoreReason(_ promise: Promise<Void>) throws -> ZoneManagerIgnoreReason {
        do {
            try hang(promise)
            XCTFail("expected error")
        } catch let error as ZoneManagerIgnoreReason {
            if let state = delegate.states.first {
                switch state {
                case .didIgnore(_, let innerError as ZoneManagerIgnoreReason):
                    XCTAssertEqual(innerError, error)
                default:
                    XCTFail("incorrect state was logged")
                }
            } else {
                XCTFail("delegate wasn't updated")
            }
            return error
        } catch {
            throw error
        }

        enum SomeError: Error {
            case blah
        }
        throw SomeError.blah
    }
}

private extension PromiseKit.Result where T == Void {
    var ignoreReason: ZoneManagerIgnoreReason? {
        switch self {
        case .rejected(let error as ZoneManagerIgnoreReason):
            return error
        default:
            return nil
        }
    }
}

class FakeZoneManagerProcessorDelegate: ZoneManagerProcessorDelegate {
    var states = [ZoneManagerState]()

    func processor(_ processor: ZoneManagerProcessor, didLog state: ZoneManagerState) {
        states.append(state)
    }
}

class FakeHassAPI: HomeAssistantAPI {
    var getAndSendPromise: Promise<Void>?
    var getAndSendInvocation: (
        trigger: LocationUpdateTrigger?,
        zone: RLMZone?
    )?

    override func GetAndSendLocation(
        trigger: LocationUpdateTrigger?,
        zone: RLMZone? = nil,
        maximumBackgroundTime: TimeInterval? = nil
    ) -> Promise<Void> {
        getAndSendInvocation = (
            trigger: trigger,
            zone: zone
        )
        return getAndSendPromise!
    }

    var submitLocationPromise: Promise<Void>?
    var submitLocationInvocation: (
        updateType: LocationUpdateTrigger,
        location: CLLocation?,
        zone: RLMZone?
    )?

    override func SubmitLocation(
        updateType: LocationUpdateTrigger,
        location: CLLocation?,
        zone: RLMZone?
    ) -> Promise<Void> {
        submitLocationInvocation = (
            updateType: updateType,
            location: location,
            zone: zone
        )
        return submitLocationPromise!
    }
}
