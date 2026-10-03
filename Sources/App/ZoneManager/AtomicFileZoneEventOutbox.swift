import Foundation
import Shared

/// Owned by the app's single ZoneManager. All access to this file goes through this instance.
final class AtomicFileZoneEventOutbox: ZoneEventOutbox {
    enum OutboxError: Error {
        case capacityExceeded
        case deliveryAlreadyStarted
    }

    private let fileURL: URL
    private let date: () -> Date
    private let writeData: (Data, URL) throws -> Void
    private let queue = DispatchQueue(label: "io.home-assistant.ZoneEventOutbox")
    private let maximumEventCount = 100
    // Late region transitions can trigger an automation at the wrong physical location.
    private let maximumEventAge: TimeInterval = 2 * 60
    // Allow the two-hour background URLSession resource timeout plus one hour for reconciliation.
    private let maximumStartedEventAge: TimeInterval = 3 * 60 * 60

    init(
        fileURL: URL = URL.applicationSupportDirectory.appendingPathComponent("zone-event-outbox-v1.json"),
        date: @escaping () -> Date = { Current.date() },
        writeData: @escaping (Data, URL) throws -> Void = { data, url in
            try data.write(to: url, options: .atomic)
        }
    ) {
        self.fileURL = fileURL
        self.date = date
        self.writeData = writeData
    }

    func pendingEvents() throws -> [PendingZoneEvent] {
        try queue.sync {
            let storedEvents = try load()
            let pendingEvents = freshEvents(from: storedEvents, at: date())
            if pendingEvents != storedEvents {
                do {
                    try save(pendingEvents)
                } catch {
                    // Expiry is deterministic; a cleanup write failure must not block delivery.
                    Current.Log.error("Zone event outbox cleanup failed: \(error)")
                }
            }
            return pendingEvents
        }
    }

    func append(_ event: PendingZoneEvent) throws {
        try queue.sync {
            guard event.deliveryStartedAt == nil else { throw OutboxError.deliveryAlreadyStarted }
            let now = date()
            let storedEvents = try load()
            guard isFresh(event, at: now) else {
                logDrop(event, reason: "expired before append")
                return
            }

            var events = freshEvents(from: storedEvents, at: now)
            guard !events.contains(where: { $0.id == event.id }) else { return }
            var dropped: [(PendingZoneEvent, String)] = []
            if event.isBeacon,
               let previous = events.last,
               previous.deliveryStartedAt == nil,
               previous.eventType == event.eventType,
               isSameBeaconZone(previous, event) {
                dropped.append((events.removeLast(), "coalesced"))
            }
            // Keep in-flight identities until their bounded reconciliation window expires.
            while events.count >= maximumEventCount {
                guard let index = events.firstIndex(where: { $0.deliveryStartedAt == nil }) else {
                    logDrop(event, reason: "capacity exceeded by started deliveries")
                    throw OutboxError.capacityExceeded
                }
                dropped.append((events.remove(at: index), "capacity"))
            }
            events.append(event)
            try save(events)
            for (event, reason) in dropped {
                logDrop(event, reason: reason)
            }
        }
    }

    func markDeliveryStarted(id: UUID, at date: Date) throws {
        // Repeated marking must not extend a stuck event's reconciliation deadline.
        try update(id: id) {
            if $0.deliveryStartedAt == nil { $0.deliveryStartedAt = date }
        }
    }

    func clearDeliveryStarted(id: UUID) throws {
        try update(id: id) { $0.deliveryStartedAt = nil }
    }

    func remove(id: UUID) throws {
        try queue.sync {
            var events = try load()
            let count = events.count
            events.removeAll { $0.id == id }
            guard events.count != count else { return }
            try save(events)
        }
    }

    private func update(id: UUID, mutation: (inout PendingZoneEvent) -> Void) throws {
        try queue.sync {
            let storedEvents = try load()
            var events = freshEvents(from: storedEvents, at: date())
            if let index = events.firstIndex(where: { $0.id == id }) {
                mutation(&events[index])
            }
            if events != storedEvents {
                try save(events)
            }
        }
    }

    private func load() throws -> [PendingZoneEvent] {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return []
        }
        do {
            return try JSONDecoder().decode([PendingZoneEvent].self, from: data)
        } catch is DecodingError {
            // Preserve evidence without repeatedly stranding every subsequent region event.
            // If quarantine fails (e.g. protection/permissions), propagate it; never overwrite.
            var corruptURL = fileURL.deletingPathExtension().appendingPathExtension("corrupt.json")
            if FileManager.default.fileExists(atPath: corruptURL.path) {
                corruptURL = fileURL.deletingPathExtension()
                    .appendingPathExtension("\(UUID().uuidString).corrupt.json")
            }
            try FileManager.default.moveItem(at: fileURL, to: corruptURL)
            Current.Log.error("Quarantined corrupt zone event outbox as \(corruptURL.lastPathComponent)")
            return []
        }
    }

    private func freshEvents(from events: [PendingZoneEvent], at date: Date) -> [PendingZoneEvent] {
        events.filter { event in
            guard isFresh(event, at: date) else {
                logDrop(event, reason: event.deliveryStartedAt == nil ? "expired" : "started delivery expired")
                return false
            }
            return true
        }
    }

    private func isFresh(_ event: PendingZoneEvent, at date: Date) -> Bool {
        if let startedAt = event.deliveryStartedAt {
            return date.timeIntervalSince(startedAt) <= maximumStartedEventAge
        }
        return date.timeIntervalSince(event.createdAt) <= maximumEventAge
    }

    private func isSameBeaconZone(_ lhs: PendingZoneEvent, _ rhs: PendingZoneEvent) -> Bool {
        guard lhs.isBeacon,
              rhs.isBeacon,
              lhs.serverIdentifier == rhs.serverIdentifier,
              let lhsZone = lhs.decodedEventData?["zone"] as? String,
              let rhsZone = rhs.decodedEventData?["zone"] as? String else { return false }
        return lhsZone == rhsZone
    }

    private func logDrop(_ event: PendingZoneEvent, reason: String) {
        Current.Log.info("Zone event outbox dropped \(event.id.uuidString): \(reason)")
    }

    private func save(_ events: [PendingZoneEvent]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try writeData(JSONEncoder().encode(events), fileURL)
    }
}
