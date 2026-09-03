import Foundation
import Shared

final class AtomicFileZoneEventOutbox: ZoneEventOutbox {
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
        try queue.sync {
            let storedEvents = try load()
            let pendingEvents = freshEvents(from: storedEvents, at: date())
            if pendingEvents != storedEvents {
                try save(pendingEvents)
            }
            return pendingEvents
        }
    }

    func append(_ event: PendingZoneEvent) throws {
        try queue.sync {
            let now = date()
            guard isFresh(event, at: now) else { return }

            var events = freshEvents(from: try load(), at: now)
            guard !events.contains(where: { $0.id == event.id }) else { return }
            if event.isBeacon == true,
               let previous = events.last,
               previous.deliveryStartedAt == nil,
               previous.eventType == event.eventType,
               isSameBeaconZone(previous, event) {
                events.removeLast()
            }
            events.append(event)
            events = Array(events.suffix(maximumEventCount))
            try save(events)
        }
    }

    func markDeliveryStarted(id: UUID, at date: Date) throws {
        try update(id: id) { $0.deliveryStartedAt = date }
    }

    func clearDeliveryStarted(id: UUID) throws {
        try update(id: id) { $0.deliveryStartedAt = nil }
    }

    func remove(id: UUID) throws {
        try queue.sync {
            var events = try load()
            events.removeAll { $0.id == id }
            try save(events)
        }
    }

    private func update(id: UUID, mutation: (inout PendingZoneEvent) -> Void) throws {
        try queue.sync {
            var events = try load()
            guard let index = events.firstIndex(where: { $0.id == id }) else { return }
            mutation(&events[index])
            try save(events)
        }
    }

    private func load() throws -> [PendingZoneEvent] {
        do {
            let data = try Data(contentsOf: fileURL)
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

    private func save(_ events: [PendingZoneEvent]) throws {
        try writeData(JSONEncoder().encode(events), fileURL)
    }
}
