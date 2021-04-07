import CoreLocation
import Foundation
@testable import HomeAssistant
import PromiseKit
import RealmSwift
@testable import Shared
import XCTest

class ZoneManagerProcessorTests: XCTestCase {
    private var api: FakeHassAPI!
    private var (oneShotLocationPromise, oneShotLocationSeal) = Promise<CLLocation>.pending()
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

        if #available(iOS 13, *) {
            beaconRegion = CLBeaconRegion(
                uuid: UUID(),
                identifier: "beacon_region"
            )
        } else {
            beaconRegion = CLBeaconRegion(
                proximityUUID: UUID(),
                identifier: "beacon_region"
            )
        }

        api = FakeHassAPI(
            tokenInfo: TokenInfo(
                accessToken: "token",
                refreshToken: "token",
                expiration: Date()
            )
        )
        api.submitLocationPromise = submitLocationPromise

        Current.api = .value(api)
        Current.location.oneShotLocation = { _ in self.oneShotLocationPromise }
        delegate = FakeZoneManagerProcessorDelegate()
        processor = ZoneManagerProcessorImpl()
        processor.delegate = delegate
    }

    override func tearDown() {
        super.tearDown()
        Current.resetAPI()
    }

    func setUpZones(
        circular: (CLCircularRegion, RLMZone) -> Void = { _, _ in },
        beacon: (CLBeaconRegion, RLMZone) -> Void = { _, _ in }
    ) throws {
        try realm.write {
            circularRegionZone = with(RLMZone()) { zone in
                zone.ID = circularRegion.identifier
                zone.Radius = circularRegion.radius
                zone.Latitude = circularRegion.center.latitude
                zone.Longitude = circularRegion.center.longitude
            }
            circular(circularRegion, circularRegionZone!)

            beaconRegionZone = with(RLMZone()) { zone in
                zone.ID = beaconRegion.identifier
            }
            beacon(beaconRegion, beaconRegionZone!)

            realm.add([circularRegionZone!, beaconRegionZone!])
        }
    }

    func testNoAPIFails() throws {
        Current.api = .init(error: HomeAssistantAPI.APIError.notConfigured)
        let now = Date()
        Current.date = { now }

        let locations = [
            CLLocation(
                coordinate: .init(latitude: 123, longitude: 1.23),
                altitude: 3.45,
                horizontalAccuracy: 1.25,
                verticalAccuracy: 0.36,
                timestamp: now.addingTimeInterval(-5.0)
            ),
        ]
        let promise = processor.perform(event: ZoneManagerEvent(eventType: .locationChange(locations)))

        // we don't care which this flow wants
        let oneShotLocation = CLLocation(latitude: 1, longitude: 1)
        oneShotLocationSeal.fulfill(oneShotLocation)
        submitLocationSeal.fulfill(())

        XCTAssertThrowsError(try hang(promise)) { error in
            XCTAssertEqual(error as? HomeAssistantAPI.APIError, HomeAssistantAPI.APIError.notConfigured)
        }
    }

    func testPerformingOneShotErrors() throws {
        Current.isPerformingSingleShotLocationQuery = true
        let promise = processor.perform(event: ZoneManagerEvent(eventType: .locationChange([])))
        XCTAssertEqual(try hangForIgnoreReason(promise), .duringOneShot)
        Current.isPerformingSingleShotLocationQuery = false
    }

    func testPerformingEmptyLocations() throws {
        let promise = processor.perform(event: ZoneManagerEvent(eventType: .locationChange([])))

        XCTAssertEqual(try hangForIgnoreReason(promise), .locationMissingEntries)
    }

    func testLocationTooOld() throws {
        let wasCatalyst = Current.isCatalyst
        Current.isCatalyst = false

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

        Current.isCatalyst = wasCatalyst
    }

    func testLocationTooOldOnCatalyst() throws {
        let wasCatalyst = Current.isCatalyst
        Current.isCatalyst = true

        let now = Date()
        Current.date = { now }

        let locations = [
            CLLocation(
                coordinate: .init(latitude: 123, longitude: 1.23),
                altitude: 3.45,
                horizontalAccuracy: 1.25,
                verticalAccuracy: 0.36,
                timestamp: now.addingTimeInterval(-31.0)
            ),
        ]
        let event = ZoneManagerEvent(eventType: .locationChange(locations))
        let promise = processor.perform(event: event)

        let expectation = self.expectation(description: "promise")
        promise.ensure {
            expectation.fulfill()
        }.cauterize()

        // we don't care which this flow wants
        let oneShotLocation = CLLocation(latitude: 1, longitude: 1)
        oneShotLocationSeal.fulfill(oneShotLocation)
        submitLocationSeal.fulfill(())

        wait(for: [expectation], timeout: 10.0)

        XCTAssertEqual(api.submitLocationInvocation?.updateType, event.asTrigger())
        XCTAssertEqual(api.submitLocationInvocation?.location, oneShotLocation)
        XCTAssertNil(api.submitLocationInvocation?.zone)

        XCTAssertTrue(promise.isFulfilled)

        Current.isCatalyst = wasCatalyst
    }

    func testLocationNotTooOld() throws {
        let wasCatalyst = Current.isCatalyst
        Current.isCatalyst = false

        let now = Date()
        Current.date = { now }

        let locations = [
            CLLocation(
                coordinate: .init(latitude: 123, longitude: 1.23),
                altitude: 3.45,
                horizontalAccuracy: 1.25,
                verticalAccuracy: 0.36,
                timestamp: now.addingTimeInterval(-5.0)
            ),
        ]
        let event = ZoneManagerEvent(eventType: .locationChange(locations))
        let promise = processor.perform(event: event)

        let expectation = self.expectation(description: "promise")
        promise.ensure {
            expectation.fulfill()
        }.cauterize()

        // we don't care which this flow wants
        let oneShotLocation = CLLocation(latitude: 1, longitude: 1)
        oneShotLocationSeal.fulfill(oneShotLocation)
        submitLocationSeal.fulfill(())

        wait(for: [expectation], timeout: 10.0)

        XCTAssertEqual(api.submitLocationInvocation?.updateType, event.asTrigger())
        XCTAssertEqual(api.submitLocationInvocation?.location, oneShotLocation)
        XCTAssertNil(api.submitLocationInvocation?.zone)

        XCTAssertTrue(promise.isFulfilled)

        Current.isCatalyst = wasCatalyst
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
        try setUpZones(circular: { _, zone in
            zone.TrackingEnabled = false
        })
        let promise = processor
            .perform(event: ZoneManagerEvent(
                eventType: .region(circularRegion, .inside),
                associatedZone: circularRegionZone
            ))
        XCTAssertEqual(try hangForIgnoreReason(promise), .zoneDisabled)
    }

    func testSSIDFiltered() throws {
        try setUpZones(circular: { _, zone in
            zone.SSIDFilter.append("wifi_name")
        })
        let promise = processor
            .perform(event: ZoneManagerEvent(
                eventType: .region(circularRegion, .inside),
                associatedZone: circularRegionZone
            ))
        XCTAssertEqual(try hangForIgnoreReason(promise), .ignoredSSID("wifi_name"))
    }

    func testZoneAlreadyIn() throws {
        // e.g. small zones getting multiple regions each with differing state

        try setUpZones(circular: { _, zone in
            zone.inRegion = true
        })
        let promise = processor
            .perform(event: ZoneManagerEvent(
                eventType: .region(circularRegion, .inside),
                associatedZone: circularRegionZone
            ))

        let expectation = self.expectation(description: "promise")
        promise.ensure {
            expectation.fulfill()
        }.cauterize()

        // we don't care which this flow wants
        oneShotLocationSeal.fulfill(.init(latitude: 1, longitude: 1))
        submitLocationSeal.fulfill(())

        wait(for: [expectation], timeout: 10.0)

        XCTAssertTrue(circularRegionZone?.inRegion ?? false)
        XCTAssertTrue(promise.isFulfilled)
    }

    func testZoneAlreadyOut() throws {
        // e.g. small zones getting multiple regions each with differing state

        try setUpZones(circular: { _, zone in
            zone.inRegion = false
        })
        let promise = processor
            .perform(event: ZoneManagerEvent(
                eventType: .region(circularRegion, .outside),
                associatedZone: circularRegionZone
            ))

        let expectation = self.expectation(description: "promise")
        promise.ensure {
            expectation.fulfill()
        }.cauterize()

        oneShotLocationSeal.fulfill(.init(latitude: 1, longitude: 1))
        submitLocationSeal.fulfill(())

        wait(for: [expectation], timeout: 10.0)

        XCTAssertFalse(circularRegionZone?.inRegion ?? true)
        XCTAssertTrue(promise.isFulfilled)
    }

    func testZoneUpdatedToInside() throws {
        try setUpZones(circular: { _, zone in
            zone.inRegion = false
        })
        let promise = processor
            .perform(event: ZoneManagerEvent(
                eventType: .region(circularRegion, .inside),
                associatedZone: circularRegionZone
            ))

        let expectation = self.expectation(description: "promise")
        promise.ensure {
            expectation.fulfill()
        }.cauterize()

        oneShotLocationSeal.fulfill(.init(latitude: 1, longitude: 1))
        submitLocationSeal.fulfill(())

        wait(for: [expectation], timeout: 10.0)

        XCTAssertTrue(circularRegionZone?.inRegion ?? false)
    }

    func testZoneUpdatedToOutside() throws {
        try setUpZones(circular: { _, zone in
            zone.inRegion = true
        })
        let promise = processor
            .perform(event: ZoneManagerEvent(
                eventType: .region(circularRegion, .outside),
                associatedZone: circularRegionZone
            ))

        let expectation = self.expectation(description: "promise")
        promise.ensure {
            expectation.fulfill()
        }.cauterize()

        oneShotLocationSeal.fulfill(.init(latitude: 1, longitude: 1))
        submitLocationSeal.fulfill(())

        wait(for: [expectation], timeout: 10.0)

        XCTAssertFalse(circularRegionZone?.inRegion ?? true)
    }

    func testBeaconExitIgnored() throws {
        try setUpZones(beacon: { _, zone in
            zone.inRegion = true
        })
        let promise = processor
            .perform(event: ZoneManagerEvent(
                eventType: .region(beaconRegion, .outside),
                associatedZone: beaconRegionZone
            ))

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
        try setUpZones(circular: { _, zone in
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

        let oneShotLocation = CLLocation(latitude: 3.33, longitude: 4.44)
        oneShotLocationSeal.fulfill(oneShotLocation)
        submitLocationSeal.fulfill(())

        wait(for: [expectation], timeout: 10.0)

        XCTAssertFalse(circularRegionZone?.inRegion ?? true)

        XCTAssertEqual(api.submitLocationInvocation?.updateType, event.asTrigger())
        XCTAssertEqual(api.submitLocationInvocation?.location, oneShotLocation)
        XCTAssertEqual(api.submitLocationInvocation?.zone, circularRegionZone)

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

    func testRegionEnterProducesInsideLocation() throws {
        try setUpZones(circular: { _, zone in
            zone.inRegion = false
        })
        let event = ZoneManagerEvent(
            eventType: .region(circularRegion, .inside),
            associatedZone: circularRegionZone
        )
        let promise = processor.perform(event: event)

        let expectation = self.expectation(description: "promise")
        promise.ensure {
            expectation.fulfill()
        }.cauterize()

        let oneShotLocation = { () -> CLLocation in
            let coordinate = circularRegion.center.moving(
                distance: .init(value: circularRegion.radius - 1, unit: .meters),
                direction: .init(value: 80, unit: .degrees)
            )
            return CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        }()

        XCTAssertTrue(circularRegion.contains(oneShotLocation.coordinate))

        oneShotLocationSeal.fulfill(oneShotLocation)
        submitLocationSeal.fulfill(())

        wait(for: [expectation], timeout: 10.0)

        XCTAssertTrue(circularRegionZone?.inRegion ?? false)

        XCTAssertEqual(api.submitLocationInvocation?.updateType, event.asTrigger())
        XCTAssertEqual(api.submitLocationInvocation?.location, oneShotLocation)
        XCTAssertEqual(api.submitLocationInvocation?.zone, circularRegionZone)

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

    func testRegionExitProducesOutsideLocation() throws {
        try setUpZones(circular: { _, zone in
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

        let oneShotLocation = { () -> CLLocation in
            let coordinate = circularRegion.center.moving(
                distance: .init(value: circularRegion.radius + 10, unit: .meters),
                direction: .init(value: 80, unit: .degrees)
            )
            return CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        }()

        XCTAssertTrue(!circularRegion.contains(oneShotLocation.coordinate))

        oneShotLocationSeal.fulfill(oneShotLocation)
        submitLocationSeal.fulfill(())

        wait(for: [expectation], timeout: 10.0)

        XCTAssertFalse(circularRegionZone?.inRegion ?? true)

        XCTAssertEqual(api.submitLocationInvocation?.updateType, event.asTrigger())
        XCTAssertEqual(api.submitLocationInvocation?.location, oneShotLocation)
        XCTAssertEqual(api.submitLocationInvocation?.zone, circularRegionZone)

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

    func testRegionEnterProducesOutsideLocation() throws {
        try setUpZones(circular: { _, zone in
            zone.inRegion = false
        })
        let event = ZoneManagerEvent(
            eventType: .region(circularRegion, .inside),
            associatedZone: circularRegionZone
        )
        let promise = processor.perform(event: event)

        let expectation = self.expectation(description: "promise")
        promise.ensure {
            expectation.fulfill()
        }.cauterize()

        let oneShotLocation = { () -> CLLocation in
            let coordinate = circularRegion.center.moving(
                distance: .init(value: circularRegion.radius + 10, unit: .meters),
                direction: .init(value: 80, unit: .degrees)
            )
            return CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        }()

        XCTAssertFalse(circularRegion.contains(oneShotLocation.coordinate))

        oneShotLocationSeal.fulfill(oneShotLocation)
        submitLocationSeal.fulfill(())

        wait(for: [expectation], timeout: 10.0)

        XCTAssertTrue(circularRegionZone?.inRegion ?? false)

        XCTAssertEqual(api.submitLocationInvocation?.updateType, event.asTrigger())

        // difference! this is the mutated one!
        if let sentLocation = api.submitLocationInvocation?.location {
            let regionWithAccuracy = CLCircularRegion(
                center: circularRegion.center,
                radius: circularRegion.radius + sentLocation.horizontalAccuracy,
                identifier: ""
            )

            XCTAssertTrue(regionWithAccuracy.contains(sentLocation.coordinate))
        } else {
            XCTFail("didn't send a location")
        }

        XCTAssertEqual(api.submitLocationInvocation?.zone, circularRegionZone)

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

    func testRegionEnterProducesOutsideZone() throws {
        try setUpZones(circular: { _, zone in
            zone.inRegion = false

            // we rely on the zone's values for this scenario's fuzzing
            XCTAssertTrue(circularRegion.radius > 0 && circularRegion.radius < 100)
            XCTAssertTrue(zone.Radius > 0 && zone.Radius < 100)
        })

        // grab the region that's the direction we're going in the one shot location below
        let eventRegion = try XCTUnwrap(
            circularRegionZone?.circularRegionsForMonitoring
                .first(where: { $0.identifier.contains("240") })
        )

        let event = ZoneManagerEvent(
            eventType: .region(eventRegion, .inside),
            associatedZone: circularRegionZone
        )
        let promise = processor.perform(event: event)

        let expectation = self.expectation(description: "promise")
        promise.ensure {
            expectation.fulfill()
        }.cauterize()

        let distanceOut: CLLocationDistance = 14

        let oneShotLocation = try { () -> CLLocation in
            // moving toward one of the circle's centers guarantees we're pointed toward the intersection of all zones
            let coordinate = circularRegion.center.moving(
                distance: .init(value: circularRegion.radius + distanceOut, unit: .meters),
                direction: .init(value: 30, unit: .degrees)
            )
            let location = CLLocation(
                coordinate: coordinate,
                altitude: 0,
                horizontalAccuracy: distanceOut / 2.0 - 1,
                // less than distance to zone, big enough to overlap all 3 other zones
                verticalAccuracy: 0,
                timestamp: Date()
            )

            XCTAssertTrue(try XCTUnwrap(circularRegionZone?.circularRegionsForMonitoring.allSatisfy({ region in
                if region == eventRegion {
                    // we want to both fudge the accuracy for this region _and_ separately for the zone
                    return !region.containsWithAccuracy(location) &&
                        !circularRegion.containsWithAccuracy(
                            location.fuzzingAccuracy(by: region.distanceWithAccuracy(from: location)
                        ))
                } else {
                    // this test case is assuming the location touches _all_ the regions except for the one entering
                    return region.containsWithAccuracy(location)
                }
            })))

            // this test case is assuming this location does _not_ intersect the zone
            XCTAssertFalse(circularRegion.containsWithAccuracy(location))

            return location
        }()

        XCTAssertFalse(circularRegion.contains(oneShotLocation.coordinate))

        oneShotLocationSeal.fulfill(oneShotLocation)
        submitLocationSeal.fulfill(())

        wait(for: [expectation], timeout: 10.0)

        XCTAssertTrue(circularRegionZone?.inRegion ?? false)

        XCTAssertEqual(api.submitLocationInvocation?.updateType, event.asTrigger())

        if let sentLocation = api.submitLocationInvocation?.location {
            let regionWithAccuracy = CLCircularRegion(
                center: circularRegion.center,
                radius: circularRegion.radius + sentLocation.horizontalAccuracy,
                identifier: ""
            )

            XCTAssertTrue(regionWithAccuracy.contains(sentLocation.coordinate))
        } else {
            XCTFail("didn't send a location")
        }

        XCTAssertEqual(api.submitLocationInvocation?.zone, circularRegionZone)

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
        try setUpZones(beacon: { _, zone in
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
                case let .didIgnore(_, innerError as ZoneManagerIgnoreReason):
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
        case let .rejected(error as ZoneManagerIgnoreReason):
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

private class FakeHassAPI: HomeAssistantAPI {
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
