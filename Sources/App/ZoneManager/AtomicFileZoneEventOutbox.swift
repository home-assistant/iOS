import Foundation
import Shared

final class AtomicFileZoneEventOutbox: ZoneEventOutbox {
    enum OutboxError: Error {
        case capacityExceeded
        case coordinationDidNotRun
    }

    private let fileURL: URL
    private let date: () -> Date
    private let writeData: (Data, URL) throws -> Void
    private let queue = DispatchQueue(label: "io.home-assistant.ZoneEventOutbox")
    private let maximumEventCount = 100
    private let maximumEventAge: TimeInterval = 2 * 60

    init(
        fileURL: URL = AppConstants.AppGroupContainer.appendingPathComponent("zone-event-outbox-v1.json"),
        date: @escaping () -> Date = Date.init,
        writeData: @escaping (Data, URL) throws -> Void = { data, url in
            try data.write(to: url, options: .atomic)
        }
    ) {
        self.fileURL = fileURL
        self.date = date
        self.writeData = writeData
    }

    func pendingEvents() throws -> [PendingZoneEvent] {
        try coordinatedAccess { url in
            let storedEvents = try load(at: url)
            let pendingEvents = freshEvents(from: storedEvents, at: date())
            if pendingEvents != storedEvents {
                try save(pendingEvents, at: url)
            }
            return pendingEvents
        }
    }

    func append(_ event: PendingZoneEvent) throws {
        try coordinatedAccess { url in
            let now = date()
            let storedEvents = try load(at: url)
            guard isFresh(event, at: now) else { return }

            var events = freshEvents(from: storedEvents, at: now)
            guard !events.contains(where: { $0.id == event.id }) else { return }
            if event.isBeacon == true,
               event.deliveryStartedAt == nil,
               let previous = events.last,
               previous.deliveryStartedAt == nil,
               previous.eventType == event.eventType,
               isSameBeaconZone(previous, event) {
                events.removeLast()
            }
            // Started deliveries must remain available for reconciliation after relaunch.
            // If every slot is in flight, reject the new event without changing the store.
            while events.count >= maximumEventCount {
                guard let index = events.firstIndex(where: { $0.deliveryStartedAt == nil }) else {
                    throw OutboxError.capacityExceeded
                }
                events.remove(at: index)
            }
            events.append(event)
            try save(events, at: url)
        }
    }

    func markDeliveryStarted(id: UUID, at date: Date) throws {
        try update(id: id) { $0.deliveryStartedAt = date }
    }

    func clearDeliveryStarted(id: UUID) throws {
        try update(id: id) { $0.deliveryStartedAt = nil }
    }

    func remove(id: UUID) throws {
        try coordinatedAccess { url in
            var events = try load(at: url)
            events.removeAll { $0.id == id }
            try save(events, at: url)
        }
    }

    private func update(id: UUID, mutation: (inout PendingZoneEvent) -> Void) throws {
        try coordinatedAccess { url in
            let storedEvents = try load(at: url)
            var events = freshEvents(from: storedEvents, at: date())
            guard let index = events.firstIndex(where: { $0.id == id }) else {
                if events != storedEvents {
                    try save(events, at: url)
                }
                return
            }
            mutation(&events[index])
            try save(events, at: url)
        }
    }

    private func coordinatedAccess<T>(_ operation: (URL) throws -> T) throws -> T {
        try queue.sync {
            var result: Result<T, Error>?
            var coordinationError: NSError?
            // Atomic replacement alone does not protect a read-modify-write transaction.
            // Coordinate the entire operation across instances and cooperating processes.
            NSFileCoordinator().coordinate(
                writingItemAt: fileURL,
                options: [],
                error: &coordinationError
            ) { url in
                result = Result { try operation(url) }
            }
            if let coordinationError { throw coordinationError }
            guard let result else { throw OutboxError.coordinationDidNotRun }
            return try result.get()
        }
    }

    private func load(at url: URL) throws -> [PendingZoneEvent] {
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([PendingZoneEvent].self, from: data)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return []
        }
    }

    private func freshEvents(from events: [PendingZoneEvent], at date: Date) -> [PendingZoneEvent] {
        events.filter { isFresh($0, at: date) }
    }

    private func isFresh(_ event: PendingZoneEvent, at date: Date) -> Bool {
        event.deliveryStartedAt != nil || date.timeIntervalSince(event.createdAt) <= maximumEventAge
    }

    private func isSameBeaconZone(_ lhs: PendingZoneEvent, _ rhs: PendingZoneEvent) -> Bool {
        guard lhs.isBeacon == true,
              rhs.isBeacon == true,
              lhs.serverIdentifier == rhs.serverIdentifier,
              let lhsZone = lhs.decodedEventData?["zone"] as? String,
              let rhsZone = rhs.decodedEventData?["zone"] as? String else { return false }
        return lhsZone == rhsZone
    }

    private func save(_ events: [PendingZoneEvent], at url: URL) throws {
        try writeData(JSONEncoder().encode(events), url)
    }
}
