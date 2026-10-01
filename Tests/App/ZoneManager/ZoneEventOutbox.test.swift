import Foundation
@testable import HomeAssistant
@testable import Shared
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
            createdAt: Current.date(),
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
            eventData: ["zone": "zone.beacon"],
            createdAt: Current.date()
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
            createdAt: Current.date(),
            isBeacon: true
        )
        let latestEntry = try PendingZoneEvent(
            serverIdentifier: "server-id",
            eventType: "ios.zone_entered",
            eventData: ["zone": "zone.beacon"],
            createdAt: Current.date(),
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
            createdAt: Current.date(),
            isBeacon: true
        )
        let exit = try PendingZoneEvent(
            serverIdentifier: "server-id",
            eventType: "ios.zone_exited",
            eventData: ["zone": "zone.beacon"],
            createdAt: Current.date(),
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
            createdAt: Current.date(),
            isBeacon: true
        )
        let exit = try PendingZoneEvent(
            serverIdentifier: "server-id",
            eventType: "ios.zone_exited",
            eventData: ["zone": "zone.beacon"],
            createdAt: Current.date(),
            isBeacon: true
        )
        let reentry = try PendingZoneEvent(
            serverIdentifier: "server-id",
            eventType: "ios.zone_entered",
            eventData: ["zone": "zone.beacon"],
            createdAt: Current.date(),
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
            createdAt: Current.date(),
            isBeacon: true
        )
        let garageEntry = try PendingZoneEvent(
            serverIdentifier: "server-id",
            eventType: "ios.zone_entered",
            eventData: ["zone": "zone.garage"],
            createdAt: Current.date(),
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
        try JSONEncoder().encode([event]).write(to: fileURL, options: .atomic)

        let reloadedOutbox = AtomicFileZoneEventOutbox(fileURL: fileURL, date: { now })

        XCTAssertEqual(try reloadedOutbox.pendingEvents(), [event])
    }

    func testWriteFailureIsPropagated() throws {
        struct TestError: Error {}
        let event = try PendingZoneEvent(
            serverIdentifier: "server-id",
            eventType: "ios.zone_entered",
            eventData: ["zone": "zone.beacon"],
            createdAt: Current.date()
        )
        let outbox = AtomicFileZoneEventOutbox(
            fileURL: fileURL,
            writeData: { _, _ in throw TestError() }
        )

        XCTAssertThrowsError(try outbox.append(event)) { error in
            XCTAssertTrue(error is TestError)
        }
    }

    func testCorruptStoreIsQuarantinedAndReadRecovers() throws {
        let corrupt = Data("not-json".utf8)
        try corrupt.write(to: fileURL, options: .atomic)
        let outbox = AtomicFileZoneEventOutbox(fileURL: fileURL)
        XCTAssertTrue(try outbox.pendingEvents().isEmpty)
        let quarantine = fileURL.deletingPathExtension().appendingPathExtension("corrupt.json")
        XCTAssertEqual(try Data(contentsOf: quarantine), corrupt)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        XCTAssertTrue(try outbox.pendingEvents().isEmpty)
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
        try JSONEncoder().encode([event]).write(to: fileURL, options: .atomic)
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
        let event = try makeEvent(started: true)
        let original = try JSONEncoder().encode([event])
        try original.write(to: fileURL, options: .atomic)
        let outbox = AtomicFileZoneEventOutbox(
            fileURL: fileURL,
            date: { now },
            writeData: { _, _ in throw TestError() }
        )
        let mutations: [() throws -> Void] = [
            { try outbox.append(self.makeEvent()) },
            { try outbox.clearDeliveryStarted(id: event.id) },
            { try outbox.remove(id: event.id) },
        ]
        for mutation in mutations {
            XCTAssertThrowsError(try mutation()) { XCTAssertTrue($0 is TestError) }
            XCTAssertEqual(try Data(contentsOf: fileURL), original)
        }
        let expired = AtomicFileZoneEventOutbox(
            fileURL: fileURL,
            date: { now.addingTimeInterval(10801) },
            writeData: { _, _ in throw TestError() }
        )
        XCTAssertTrue(try expired.pendingEvents().isEmpty)
        XCTAssertEqual(try Data(contentsOf: fileURL), original)
    }

    func testCorruptStoreAppendPreservesEvidenceAndNewEventSurvivesRelaunch() throws {
        let original = Data("not-json".utf8)
        try original.write(to: fileURL, options: .atomic)
        let now = Date(timeIntervalSince1970: 1000)
        let outbox = AtomicFileZoneEventOutbox(fileURL: fileURL, date: { now })
        let event = try makeEvent()
        try outbox.append(event)
        let quarantine = fileURL.deletingPathExtension().appendingPathExtension("corrupt.json")
        XCTAssertEqual(try Data(contentsOf: quarantine), original)
        XCTAssertEqual(try AtomicFileZoneEventOutbox(fileURL: fileURL, date: { now }).pendingEvents(), [event])
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

    func testInvalidEventPayloadIsRejected() {
        let invalidPayloads: [[String: Any]] = [
            ["invalid": Date()],
            ["nested": ["values": [Date()]]],
            ["invalid": Double.nan],
            ["invalid": Double.infinity],
        ]
        for payload in invalidPayloads {
            XCTAssertThrowsError(try PendingZoneEvent(
                serverIdentifier: "server-id",
                eventType: "ios.zone_entered",
                eventData: payload,
                createdAt: Current.date()
            )) { error in
                XCTAssertEqual(error as? PendingZoneEvent.PayloadError, .invalidJSONObject)
            }
        }
    }

    func testValidNestedEventPayloadRoundTrips() throws {
        let payload: [String: Any] = [
            "zone": "zone.home",
            "nested": ["values": [true, 42, "text", NSNull()] as [Any]],
        ]
        let event = try PendingZoneEvent(
            serverIdentifier: "server-id",
            eventType: "ios.zone_entered",
            eventData: payload,
            createdAt: Current.date()
        )
        let decoded = try XCTUnwrap(event.decodedEventData)
        XCTAssertTrue(NSDictionary(dictionary: payload).isEqual(to: decoded))
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
        try JSONEncoder().encode([first]).write(to: fileURL, options: .atomic)
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

    func testStartedAppendIsRejectedWithoutChangingStore() throws {
        let now = Date(timeIntervalSince1970: 1000)
        let outbox = AtomicFileZoneEventOutbox(fileURL: fileURL, date: { now })
        let queued = try makeEvent()
        try outbox.append(queued)
        let original = try Data(contentsOf: fileURL)
        XCTAssertThrowsError(try outbox.append(makeEvent(started: true))) { error in
            XCTAssertEqual(error as? AtomicFileZoneEventOutbox.OutboxError, .deliveryAlreadyStarted)
        }
        XCTAssertEqual(try Data(contentsOf: fileURL), original)
        XCTAssertEqual(try outbox.pendingEvents(), [queued])
    }

    func testMarkingExpiredEventDoesNotReviveIt() throws {
        let now = Date(timeIntervalSince1970: 1000)
        let event = try makeEvent()
        try JSONEncoder().encode([event]).write(to: fileURL, options: .atomic)
        let outbox = AtomicFileZoneEventOutbox(fileURL: fileURL, date: { now.addingTimeInterval(121) })

        try outbox.markDeliveryStarted(id: event.id, at: now.addingTimeInterval(121))

        XCTAssertTrue(try outbox.pendingEvents().isEmpty)
        XCTAssertEqual(try JSONDecoder().decode([PendingZoneEvent].self, from: Data(contentsOf: fileURL)), [])
    }

    func testMarkingEventAtExpiryBoundaryStillStartsDelivery() throws {
        let now = Date(timeIntervalSince1970: 1000)
        let event = try makeEvent()
        try JSONEncoder().encode([event]).write(to: fileURL, options: .atomic)
        let outbox = AtomicFileZoneEventOutbox(fileURL: fileURL, date: { now.addingTimeInterval(120) })
        try outbox.markDeliveryStarted(id: event.id, at: now.addingTimeInterval(120))
        var expected = event
        expected.deliveryStartedAt = now.addingTimeInterval(120)
        let reloaded = AtomicFileZoneEventOutbox(fileURL: fileURL, date: { now.addingTimeInterval(500) })
        XCTAssertEqual(try reloaded.pendingEvents(), [expected])
    }

    func testExpiredAppendRecoversCorruptStoreWithoutKeepingStaleEvent() throws {
        let original = Data("not-json".utf8)
        try original.write(to: fileURL, options: .atomic)
        let now = Date(timeIntervalSince1970: 1000)
        let outbox = AtomicFileZoneEventOutbox(fileURL: fileURL, date: { now.addingTimeInterval(121) })
        try outbox.append(makeEvent())
        XCTAssertTrue(try outbox.pendingEvents().isEmpty)
        XCTAssertEqual(
            try Data(contentsOf: fileURL.deletingPathExtension().appendingPathExtension("corrupt.json")), original
        )
    }

    func testExpiredUpdateCleanupWriteFailurePreservesStore() throws {
        struct TestError: Error {}
        let now = Date(timeIntervalSince1970: 1000)
        let event = try makeEvent()
        let original = try JSONEncoder().encode([event])
        try original.write(to: fileURL, options: .atomic)
        let outbox = AtomicFileZoneEventOutbox(
            fileURL: fileURL,
            date: { now.addingTimeInterval(121) },
            writeData: { _, _ in throw TestError() }
        )
        XCTAssertThrowsError(try outbox.markDeliveryStarted(id: event.id, at: now)) {
            XCTAssertTrue($0 is TestError)
        }
        XCTAssertEqual(try Data(contentsOf: fileURL), original)
    }

    func testConcurrentCallsToSingleOwnerPreserveEveryAppend() throws {
        let now = Date(timeIntervalSince1970: 1000)
        let events = try (0 ..< 40).map { _ in try makeEvent() }
        let outbox = AtomicFileZoneEventOutbox(fileURL: fileURL, date: { now })
        DispatchQueue.concurrentPerform(iterations: events.count) { index in
            do {
                try outbox.append(events[index])
            } catch {
                XCTFail("Concurrent append failed: \(error)")
            }
        }
        let stored = try AtomicFileZoneEventOutbox(fileURL: fileURL, date: { now }).pendingEvents()
        XCTAssertEqual(stored.count, events.count)
        XCTAssertEqual(Set(stored.map(\.id)), Set(events.map(\.id)))
    }

    func testStartedDeadlineAllowsReconciliationThenUnblocksNextServer() throws {
        let created = Date(timeIntervalSince1970: 1000)
        var now = created.addingTimeInterval(10800)
        let stuck = try makeEvent(started: true)
        let next = try PendingZoneEvent(
            serverIdentifier: "other-server", eventType: "ios.zone_entered",
            eventData: ["zone": "zone.home"], createdAt: now
        )
        try JSONEncoder().encode([stuck, next]).write(to: fileURL, options: .atomic)
        let outbox = AtomicFileZoneEventOutbox(fileURL: fileURL, date: { now })
        XCTAssertEqual(try outbox.pendingEvents(), [stuck, next])
        now = now.addingTimeInterval(1)
        XCTAssertEqual(try outbox.pendingEvents(), [next])
        XCTAssertEqual(try AtomicFileZoneEventOutbox(fileURL: fileURL, date: { now }).pendingEvents(), [next])
    }

    func testStartedDeadlineFreesFullCapacity() throws {
        let now = Date(timeIntervalSince1970: 11801)
        let expired = try (0 ..< 100).map { _ in try makeEvent(started: true) }
        try JSONEncoder().encode(expired).write(to: fileURL, options: .atomic)
        let incoming = try makeEvent(createdAt: now)
        let outbox = AtomicFileZoneEventOutbox(fileURL: fileURL, date: { now })
        try outbox.append(incoming)
        XCTAssertEqual(try outbox.pendingEvents(), [incoming])
    }

    func testRepeatedMarkCannotExtendStartedDeadline() throws {
        let created = Date(timeIntervalSince1970: 1000)
        var now = created
        let event = try makeEvent()
        let outbox = AtomicFileZoneEventOutbox(fileURL: fileURL, date: { now })
        try outbox.append(event)
        try outbox.markDeliveryStarted(id: event.id, at: now)
        now = created.addingTimeInterval(10800)
        try outbox.markDeliveryStarted(id: event.id, at: now)
        XCTAssertEqual(try outbox.pendingEvents().first?.deliveryStartedAt, created)
        now = now.addingTimeInterval(1)
        XCTAssertTrue(try outbox.pendingEvents().isEmpty)
    }

    func testPruneWriteFailureReturnsFreshEventsAndLaterMutationPersistsCleanup() throws {
        struct TestError: Error {}
        let now = Date(timeIntervalSince1970: 2000)
        let expired = try makeEvent()
        let fresh = try makeEvent(createdAt: now)
        let original = try JSONEncoder().encode([expired, fresh])
        try original.write(to: fileURL, options: .atomic)
        var failWrite = true
        let outbox = AtomicFileZoneEventOutbox(fileURL: fileURL, date: { now }, writeData: { data, url in
            if failWrite { throw TestError() }
            try data.write(to: url, options: .atomic)
        })
        XCTAssertEqual(try outbox.pendingEvents(), [fresh])
        XCTAssertEqual(try Data(contentsOf: fileURL), original)
        failWrite = false
        try outbox.markDeliveryStarted(id: fresh.id, at: now)
        var started = fresh
        started.deliveryStartedAt = now
        XCTAssertEqual(try JSONDecoder().decode([PendingZoneEvent].self, from: Data(contentsOf: fileURL)), [started])
    }

    func testRepeatedCorruptionPreservesBothQuarantines() throws {
        let outbox = AtomicFileZoneEventOutbox(fileURL: fileURL)
        let first = Data("broken-first".utf8)
        let second = Data("broken-second".utf8)
        try first.write(to: fileURL, options: .atomic)
        XCTAssertTrue(try outbox.pendingEvents().isEmpty)
        try second.write(to: fileURL, options: .atomic)
        XCTAssertTrue(try outbox.pendingEvents().isEmpty)
        let files = try FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
        XCTAssertEqual(files.count, 2)
        XCTAssertEqual(try Set(files.map { try Data(contentsOf: $0) }), Set([first, second]))
    }

    func testMalformedEntryQuarantinesWholeArrayAndAllowsNewAppend() throws {
        let now = Date(timeIntervalSince1970: 1000)
        let event = try makeEvent()
        let encoded = try JSONEncoder().encode(event)
        let original = Data("[".utf8) + encoded + Data(",{}]".utf8)
        try original.write(to: fileURL, options: .atomic)
        let outbox = AtomicFileZoneEventOutbox(fileURL: fileURL, date: { now })
        try outbox.append(event)
        XCTAssertEqual(try outbox.pendingEvents(), [event])
        XCTAssertEqual(
            try Data(contentsOf: fileURL.deletingPathExtension().appendingPathExtension("corrupt.json")), original
        )
    }

    func testReadIOFailureDoesNotQuarantineOrOverwrite() throws {
        // Reading a directory is an I/O error, not malformed JSON.
        try FileManager.default.createDirectory(at: fileURL, withIntermediateDirectories: false)
        let outbox = AtomicFileZoneEventOutbox(fileURL: fileURL)
        XCTAssertThrowsError(try outbox.pendingEvents())
        XCTAssertThrowsError(try outbox.append(makeEvent(createdAt: Current.date())))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directoryURL.path), ["outbox.json"])
    }

    func testUnknownRemovalDoesNotCreateFileOrWriteExistingStore() throws {
        struct TestError: Error {}
        let now = Date(timeIntervalSince1970: 1000)
        let outbox = AtomicFileZoneEventOutbox(fileURL: fileURL, date: { now }, writeData: { _, _ in
            throw TestError()
        })
        try outbox.remove(id: UUID())
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
        let original = try JSONEncoder().encode([makeEvent()])
        try original.write(to: fileURL, options: .atomic)
        try outbox.remove(id: UUID())
        XCTAssertEqual(try Data(contentsOf: fileURL), original)
    }

    func testDefaultClockReadsCurrentDateDynamically() throws {
        let originalDate = Current.date
        defer { Current.date = originalDate }
        let now = Date(timeIntervalSince1970: 1000)
        Current.date = { now }
        let outbox = AtomicFileZoneEventOutbox(fileURL: fileURL)
        let event = try makeEvent(createdAt: Current.date())
        try outbox.append(event)
        XCTAssertEqual(try outbox.pendingEvents(), [event])
        Current.date = { now.addingTimeInterval(121) }
        XCTAssertTrue(try outbox.pendingEvents().isEmpty)
    }

    func testAppendCreatesMissingApplicationSupportParent() throws {
        let now = Date(timeIntervalSince1970: 1000)
        let nestedURL = directoryURL.appendingPathComponent("Application Support/outbox.json")
        let outbox = AtomicFileZoneEventOutbox(fileURL: nestedURL, date: { now })
        let event = try makeEvent()
        try outbox.append(event)
        XCTAssertEqual(try AtomicFileZoneEventOutbox(fileURL: nestedURL, date: { now }).pendingEvents(), [event])
    }
}
