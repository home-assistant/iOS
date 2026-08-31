import Foundation
@testable import HomeAssistant
import XCTest

final class ZoneEventOutboxTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "ZoneEventOutboxTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testEventSurvivesOutboxRecreationUntilRemoved() throws {
        let event = try PendingZoneEvent(
            serverIdentifier: "server-id",
            eventType: "ios.zone_entered",
            eventData: ["zone": "zone.beacon"],
            isBeacon: true
        )
        var outbox: UserDefaultsZoneEventOutbox? = UserDefaultsZoneEventOutbox(
            defaults: defaults,
            key: "outbox"
        )
        outbox?.append(event)

        outbox = UserDefaultsZoneEventOutbox(defaults: defaults, key: "outbox")
        XCTAssertEqual(outbox?.pendingEvents, [event])
        XCTAssertEqual(outbox?.pendingEvents.first?.decodedEventData?["zone"] as? String, "zone.beacon")
        XCTAssertEqual(outbox?.pendingEvents.first?.isBeacon, true)

        outbox?.remove(id: event.id)
        XCTAssertTrue(outbox?.pendingEvents.isEmpty == true)
    }

    func testAppendingSameEventTwiceDoesNotDuplicateIt() throws {
        let event = try PendingZoneEvent(
            serverIdentifier: "server-id",
            eventType: "ios.zone_exited",
            eventData: ["zone": "zone.beacon"]
        )
        let outbox = UserDefaultsZoneEventOutbox(defaults: defaults, key: "outbox")

        outbox.append(event)
        outbox.append(event)

        XCTAssertEqual(outbox.pendingEvents, [event])
    }

    func testExpiredEventIsRemovedWhenOutboxIsRead() throws {
        let now = Date()
        let event = try PendingZoneEvent(
            serverIdentifier: "server-id",
            eventType: "ios.zone_entered",
            eventData: ["zone": "zone.beacon"],
            createdAt: now.addingTimeInterval(-121),
            isBeacon: true
        )
        var outbox: UserDefaultsZoneEventOutbox? = UserDefaultsZoneEventOutbox(
            defaults: defaults,
            key: "outbox",
            date: { now.addingTimeInterval(-121) }
        )
        outbox?.append(event)

        outbox = UserDefaultsZoneEventOutbox(defaults: defaults, key: "outbox", date: { now })

        XCTAssertTrue(outbox?.pendingEvents.isEmpty == true)
        XCTAssertNil(defaults.data(forKey: "outbox"))
    }

    func testLatestBeaconTransitionReplacesQueuedTransitionForSameZone() throws {
        let entry = try PendingZoneEvent(
            serverIdentifier: "server-id",
            eventType: "ios.zone_entered",
            eventData: ["zone": "zone.beacon"],
            isBeacon: true
        )
        let exit = try PendingZoneEvent(
            serverIdentifier: "server-id",
            eventType: "ios.zone_exited",
            eventData: ["zone": "zone.beacon"],
            isBeacon: true
        )
        let outbox = UserDefaultsZoneEventOutbox(defaults: defaults, key: "outbox")

        outbox.append(entry)
        outbox.append(exit)

        XCTAssertEqual(outbox.pendingEvents, [exit])
    }

    func testBeaconTransitionsForDifferentZonesRemainQueued() throws {
        let beaconEntry = try PendingZoneEvent(
            serverIdentifier: "server-id",
            eventType: "ios.zone_entered",
            eventData: ["zone": "zone.beacon"],
            isBeacon: true
        )
        let garageEntry = try PendingZoneEvent(
            serverIdentifier: "server-id",
            eventType: "ios.zone_entered",
            eventData: ["zone": "zone.garage"],
            isBeacon: true
        )
        let outbox = UserDefaultsZoneEventOutbox(defaults: defaults, key: "outbox")

        outbox.append(beaconEntry)
        outbox.append(garageEntry)

        XCTAssertEqual(outbox.pendingEvents, [beaconEntry, garageEntry])
    }

    func testExpiredNonBeaconEventIsAlsoRemoved() throws {
        let now = Date()
        let event = try PendingZoneEvent(
            serverIdentifier: "server-id",
            eventType: "ios.zone_entered",
            eventData: ["zone": "zone.home"],
            createdAt: now.addingTimeInterval(-121),
            isBeacon: false
        )
        let outbox = UserDefaultsZoneEventOutbox(
            defaults: defaults,
            key: "outbox",
            date: { now.addingTimeInterval(-121) }
        )

        outbox.append(event)

        let reloadedOutbox = UserDefaultsZoneEventOutbox(defaults: defaults, key: "outbox", date: { now })
        XCTAssertTrue(reloadedOutbox.pendingEvents.isEmpty)
    }
}
