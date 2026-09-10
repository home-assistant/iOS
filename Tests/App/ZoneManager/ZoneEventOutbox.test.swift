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

    private func makeEvent(
        createdAt: Date = Date(timeIntervalSince1970: 1000),
        started: Bool = false
    ) throws -> PendingZoneEvent {
        try PendingZoneEvent(
            serverIdentifier: "server-id",
            eventType: "ios.zone_entered",
            eventData: ["zone": "zone.home"],
            createdAt: createdAt,
            deliveryStartedAt: started ? createdAt : nil
        )
    }

    func testCapacityEvictsOldestUnstartedEventButPreservesStartedEvent() throws {
        let now = Date(timeIntervalSince1970: 1000)
        let started = try makeEvent(started: true)
        let queued = try (0 ..< 99).map { _ in try makeEvent() }
        let original = [started] + queued
        try JSONEncoder().encode(original).write(to: fileURL, options: .atomic)
        let outbox = AtomicFileZoneEventOutbox(fileURL: fileURL, date: { now })
        let incoming = try makeEvent()

        try outbox.append(incoming)

        let reloaded = AtomicFileZoneEventOutbox(fileURL: fileURL, date: { now })
        XCTAssertEqual(try reloaded.pendingEvents(), [started] + Array(queued.dropFirst()) + [incoming])
    }

    func testFullInFlightStoreRejectsAppendWithoutChangingFile() throws {
        let now = Date(timeIntervalSince1970: 1000)
        let events = try (0 ..< 100).map { _ in try makeEvent(started: true) }
        let original = try JSONEncoder().encode(events)
        try original.write(to: fileURL, options: .atomic)
        let outbox = AtomicFileZoneEventOutbox(fileURL: fileURL, date: { now })

        XCTAssertThrowsError(try outbox.append(makeEvent())) { error in
            guard case AtomicFileZoneEventOutbox.OutboxError.capacityExceeded = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
        XCTAssertEqual(try Data(contentsOf: fileURL), original)
        XCTAssertEqual(try outbox.pendingEvents(), events)
    }

    func testClearingStartedDeliveryPersistsAndAllowsExpiration() throws {
        let now = Date(timeIntervalSince1970: 1000)
        let event = try makeEvent(started: true)
        let outbox = AtomicFileZoneEventOutbox(fileURL: fileURL, date: { now })
        try outbox.append(event)
        try outbox.clearDeliveryStarted(id: event.id)

        let reloaded = AtomicFileZoneEventOutbox(fileURL: fileURL, date: { now })
        var expected = event
        expected.deliveryStartedAt = nil
        XCTAssertEqual(try reloaded.pendingEvents(), [expected])
        let expired = AtomicFileZoneEventOutbox(fileURL: fileURL, date: { now.addingTimeInterval(121) })
        XCTAssertTrue(try expired.pendingEvents().isEmpty)
    }

    func testFreshnessBoundaryAndExpiredAppend() throws {
        let now = Date(timeIntervalSince1970: 1000)
        let outbox = AtomicFileZoneEventOutbox(fileURL: fileURL, date: { now })
        let boundary = try makeEvent(createdAt: now.addingTimeInterval(-120))
        try outbox.append(makeEvent(createdAt: now.addingTimeInterval(-121)))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        try outbox.append(boundary)
        XCTAssertEqual(try outbox.pendingEvents(), [boundary])
    }

    func testUnknownDeliveryUpdatesDoNotCreateFile() throws {
        let outbox = AtomicFileZoneEventOutbox(fileURL: fileURL)
        try outbox.markDeliveryStarted(id: UUID(), at: Date())
        try outbox.clearDeliveryStarted(id: UUID())
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertTrue(try outbox.pendingEvents().isEmpty)
    }

    func testFailedMutationsLeaveStoredEventUnchanged() throws {
        struct TestError: Error {}
        let now = Date(timeIntervalSince1970: 1000)
        let event = try makeEvent()
        let original = try JSONEncoder().encode([event])
        try original.write(to: fileURL, options: .atomic)
        let outbox = AtomicFileZoneEventOutbox(
            fileURL: fileURL,
            date: { now },
            writeData: { _, _ in throw TestError() }
        )
        let mutations: [() throws -> Void] = [
            { try outbox.append(self.makeEvent()) },
            { try outbox.markDeliveryStarted(id: event.id, at: now) },
            { try outbox.clearDeliveryStarted(id: event.id) },
            { try outbox.remove(id: event.id) },
        ]
        for mutation in mutations {
            XCTAssertThrowsError(try mutation()) { XCTAssertTrue($0 is TestError) }
            XCTAssertEqual(try Data(contentsOf: fileURL), original)
        }
        let expired = AtomicFileZoneEventOutbox(
            fileURL: fileURL,
            date: { now.addingTimeInterval(121) },
            writeData: { _, _ in throw TestError() }
        )
        XCTAssertThrowsError(try expired.pendingEvents()) { XCTAssertTrue($0 is TestError) }
        XCTAssertEqual(try Data(contentsOf: fileURL), original)
    }

    func testCorruptStoreIsNotOverwrittenByAppend() throws {
        let original = Data("not-json".utf8)
        try original.write(to: fileURL, options: .atomic)
        let outbox = AtomicFileZoneEventOutbox(fileURL: fileURL)
        XCTAssertThrowsError(try outbox.append(makeEvent(createdAt: Date())))
        XCTAssertEqual(try Data(contentsOf: fileURL), original)
    }

    func testBeaconCoalescingDoesNotCrossServerOrMissingZone() throws {
        let now = Date(timeIntervalSince1970: 1000)
        let events = try [
            ("server-a", ["zone": "zone.home"]),
            ("server-b", ["zone": "zone.home"]),
            ("server-b", [String: String]()),
            ("server-b", [String: String]()),
        ].map { server, data in
            try PendingZoneEvent(
                serverIdentifier: server,
                eventType: "ios.zone_entered",
                eventData: data,
                createdAt: now,
                isBeacon: true
            )
        }
        let outbox = AtomicFileZoneEventOutbox(fileURL: fileURL, date: { now })
        for event in events {
            try outbox.append(event)
        }
        XCTAssertEqual(try outbox.pendingEvents(), events)
    }

    func testLegacyEventWithoutOptionalMetadataDecodes() throws {
        let event = try makeEvent()
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(event)) as? [String: Any])
        object.removeValue(forKey: "isBeacon")
        object.removeValue(forKey: "deliveryStartedAt")
        let decoded = try JSONDecoder().decode(
            PendingZoneEvent.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        XCTAssertEqual(decoded.id, event.id)
        XCTAssertEqual(decoded.eventData, event.eventData)
        XCTAssertNil(decoded.isBeacon)
        XCTAssertNil(decoded.deliveryStartedAt)
    }

    func testInvalidEventPayloadIsRejected() {
        XCTAssertThrowsError(try PendingZoneEvent(
            serverIdentifier: "server-id",
            eventType: "ios.zone_entered",
            eventData: ["invalid": Date()]
        ))
    }

    func testStartedBeaconIsNotCoalescedWithSameTransition() throws {
        let now = Date(timeIntervalSince1970: 1000)
        let first = try PendingZoneEvent(
            serverIdentifier: "server-id",
            eventType: "ios.zone_entered",
            eventData: ["zone": "zone.home"],
            createdAt: now,
            isBeacon: true,
            deliveryStartedAt: now
        )
        let second = try PendingZoneEvent(
            serverIdentifier: "server-id",
            eventType: first.eventType,
            eventData: ["zone": "zone.home"],
            createdAt: now,
            isBeacon: true
        )
        let outbox = AtomicFileZoneEventOutbox(fileURL: fileURL, date: { now })
        try outbox.append(first)
        try outbox.append(second)
        XCTAssertEqual(try outbox.pendingEvents(), [first, second])
    }

    func testUnreadableEventPayloadDoesNotPreventOtherMetadataDecoding() throws {
        let event = try makeEvent()
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(event)) as? [String: Any])
        object["eventData"] = Data("invalid-json".utf8).base64EncodedString()
        let decoded = try JSONDecoder().decode(
            PendingZoneEvent.self,
            from: JSONSerialization.data(withJSONObject: object)
        )
        XCTAssertEqual(decoded.id, event.id)
        XCTAssertNil(decoded.decodedEventData)
    }
}
