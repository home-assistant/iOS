import Foundation
@testable import HomeAssistant
import XCTest

final class ZoneEventOutboxTests: XCTestCase {
    private var directoryURL: URL!
    private var fileURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        fileURL = directoryURL.appendingPathComponent("outbox.json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directoryURL)
        directoryURL = nil
        fileURL = nil
        try super.tearDownWithError()
    }

    func testEventSurvivesOutboxRecreationUntilRemoved() throws {
        let event = try PendingZoneEvent(
            serverIdentifier: "server-id",
            eventType: "ios.zone_entered",
            eventData: ["zone": "zone.beacon"],
            isBeacon: true
        )
        var outbox: AtomicFileZoneEventOutbox? = AtomicFileZoneEventOutbox(fileURL: fileURL)
        try outbox?.append(event)

        outbox = AtomicFileZoneEventOutbox(fileURL: fileURL)
        XCTAssertEqual(try outbox?.pendingEvents(), [event])
        XCTAssertEqual(try outbox?.pendingEvents().first?.decodedEventData?["zone"] as? String, "zone.beacon")
        XCTAssertEqual(try outbox?.pendingEvents().first?.isBeacon, true)

        try outbox?.remove(id: event.id)
        XCTAssertTrue(try outbox?.pendingEvents().isEmpty == true)
    }

    func testAppendingSameEventTwiceDoesNotDuplicateIt() throws {
        let event = try PendingZoneEvent(
            serverIdentifier: "server-id",
            eventType: "ios.zone_exited",
            eventData: ["zone": "zone.beacon"]
        )
        let outbox = AtomicFileZoneEventOutbox(fileURL: fileURL)

        try outbox.append(event)
        try outbox.append(event)

        XCTAssertEqual(try outbox.pendingEvents(), [event])
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
        var outbox: AtomicFileZoneEventOutbox? = AtomicFileZoneEventOutbox(
            fileURL: fileURL,
            date: { now.addingTimeInterval(-121) }
        )
        try outbox?.append(event)

        outbox = AtomicFileZoneEventOutbox(fileURL: fileURL, date: { now })

        XCTAssertTrue(try outbox?.pendingEvents().isEmpty == true)
        XCTAssertEqual(try Data(contentsOf: fileURL), try JSONEncoder().encode([PendingZoneEvent]()))
    }

    func testLatestRedundantUnstartedBeaconTransitionReplacesPreviousTransition() throws {
        let firstEntry = try PendingZoneEvent(
            serverIdentifier: "server-id",
            eventType: "ios.zone_entered",
            eventData: ["zone": "zone.beacon"],
            isBeacon: true
        )
        let latestEntry = try PendingZoneEvent(
            serverIdentifier: "server-id",
            eventType: "ios.zone_entered",
            eventData: ["zone": "zone.beacon"],
            isBeacon: true
        )
        let outbox = AtomicFileZoneEventOutbox(fileURL: fileURL)

        try outbox.append(firstEntry)
        try outbox.append(latestEntry)

        XCTAssertEqual(try outbox.pendingEvents(), [latestEntry])
    }

    func testInFlightBeaconTransitionIsPreservedBeforeNewTransition() throws {
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
        let outbox = AtomicFileZoneEventOutbox(fileURL: fileURL)

        try outbox.append(entry)
        try outbox.markDeliveryStarted(id: entry.id, at: Date())
        try outbox.append(exit)

        let events = try outbox.pendingEvents()
        XCTAssertEqual(events.map(\.id), [entry.id, exit.id])
        XCTAssertNotNil(events.first?.deliveryStartedAt)
    }

    func testAlternatingTransitionsRemainOrderedBehindInFlightEntry() throws {
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
        let reentry = try PendingZoneEvent(
            serverIdentifier: "server-id",
            eventType: "ios.zone_entered",
            eventData: ["zone": "zone.beacon"],
            isBeacon: true
        )
        let outbox = AtomicFileZoneEventOutbox(fileURL: fileURL)

        try outbox.append(entry)
        try outbox.markDeliveryStarted(id: entry.id, at: Date())
        try outbox.append(exit)
        try outbox.append(reentry)

        XCTAssertEqual(try outbox.pendingEvents().map(\.id), [entry.id, exit.id, reentry.id])
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
        let outbox = AtomicFileZoneEventOutbox(fileURL: fileURL)

        try outbox.append(beaconEntry)
        try outbox.append(garageEntry)

        XCTAssertEqual(try outbox.pendingEvents(), [beaconEntry, garageEntry])
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
        let outbox = AtomicFileZoneEventOutbox(
            fileURL: fileURL,
            date: { now.addingTimeInterval(-121) }
        )

        try outbox.append(event)

        let reloadedOutbox = AtomicFileZoneEventOutbox(fileURL: fileURL, date: { now })
        XCTAssertTrue(try reloadedOutbox.pendingEvents().isEmpty)
    }

    func testStartedEventSurvivesAgeCleanupForTaskReconciliation() throws {
        let now = Date()
        let event = try PendingZoneEvent(
            serverIdentifier: "server-id",
            eventType: "ios.zone_entered",
            eventData: ["zone": "zone.beacon"],
            createdAt: now.addingTimeInterval(-121),
            isBeacon: true,
            deliveryStartedAt: now.addingTimeInterval(-120)
        )
        let initialOutbox = AtomicFileZoneEventOutbox(
            fileURL: fileURL,
            date: { now.addingTimeInterval(-121) }
        )
        try initialOutbox.append(event)

        let reloadedOutbox = AtomicFileZoneEventOutbox(fileURL: fileURL, date: { now })

        XCTAssertEqual(try reloadedOutbox.pendingEvents(), [event])
    }

    func testWriteFailureIsPropagated() throws {
        struct TestError: Error {}
        let event = try PendingZoneEvent(
            serverIdentifier: "server-id",
            eventType: "ios.zone_entered",
            eventData: ["zone": "zone.beacon"]
        )
        let outbox = AtomicFileZoneEventOutbox(
            fileURL: fileURL,
            writeData: { _, _ in throw TestError() }
        )

        XCTAssertThrowsError(try outbox.append(event)) { error in
            XCTAssertTrue(error is TestError)
        }
    }

    func testCorruptStoreReadFailureIsPropagated() throws {
        try Data("not-json".utf8).write(to: fileURL, options: .atomic)
        let outbox = AtomicFileZoneEventOutbox(fileURL: fileURL)

        XCTAssertThrowsError(try outbox.pendingEvents())
    }
}
