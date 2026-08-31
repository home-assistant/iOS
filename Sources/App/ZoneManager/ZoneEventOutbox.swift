import Foundation
import Shared

struct PendingZoneEvent: Codable, Equatable {
    let id: UUID
    let serverIdentifier: String
    let eventType: String
    let eventData: Data
    let createdAt: Date
    let isBeacon: Bool?

    init(
        id: UUID = UUID(),
        serverIdentifier: String,
        eventType: String,
        eventData: [String: Any],
        createdAt: Date = Date(),
        isBeacon: Bool = false
    ) throws {
        self.id = id
        self.serverIdentifier = serverIdentifier
        self.eventType = eventType
        self.eventData = try JSONSerialization.data(withJSONObject: eventData, options: [.sortedKeys])
        self.createdAt = createdAt
        self.isBeacon = isBeacon
    }

    var decodedEventData: [String: Any]? {
        (try? JSONSerialization.jsonObject(with: eventData)) as? [String: Any]
    }
}

protocol ZoneEventOutbox: AnyObject {
    var pendingEvents: [PendingZoneEvent] { get }
    func append(_ event: PendingZoneEvent)
    func remove(id: UUID)
}

final class UserDefaultsZoneEventOutbox: ZoneEventOutbox {
    private let defaults: UserDefaults
    private let key: String
    private let date: () -> Date
    private let queue = DispatchQueue(label: "io.robbie.HomeAssistant.ZoneEventOutbox")
    private let maximumEventCount = 100
    private let maximumEventAge: TimeInterval = 2 * 60

    init(
        defaults: UserDefaults = UserDefaults(suiteName: AppConstants.AppGroupID) ?? .standard,
        key: String = "zoneEventOutbox.v1",
        date: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.key = key
        self.date = date
    }

    var pendingEvents: [PendingZoneEvent] {
        queue.sync {
            let storedEvents = load()
            let pendingEvents = freshEvents(from: storedEvents, at: date())
            if pendingEvents != storedEvents {
                save(pendingEvents)
            }
            return pendingEvents
        }
    }

    func append(_ event: PendingZoneEvent) {
        queue.sync {
            let now = date()
            guard isFresh(event, at: now) else { return }

            var events = freshEvents(from: load(), at: now)
            guard !events.contains(where: { $0.id == event.id }) else { return }
            if event.isBeacon == true {
                events.removeAll { isSameBeaconZone($0, event) }
            }
            events.append(event)
            events = Array(events.suffix(maximumEventCount))
            save(events)
        }
    }

    func remove(id: UUID) {
        queue.sync {
            var events = load()
            events.removeAll { $0.id == id }
            save(events)
        }
    }

    private func load() -> [PendingZoneEvent] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([PendingZoneEvent].self, from: data)) ?? []
    }

    private func freshEvents(from events: [PendingZoneEvent], at date: Date) -> [PendingZoneEvent] {
        events.filter { isFresh($0, at: date) }
    }

    private func isFresh(_ event: PendingZoneEvent, at date: Date) -> Bool {
        date.timeIntervalSince(event.createdAt) <= maximumEventAge
    }

    private func isSameBeaconZone(_ lhs: PendingZoneEvent, _ rhs: PendingZoneEvent) -> Bool {
        guard lhs.isBeacon == true,
              rhs.isBeacon == true,
              lhs.serverIdentifier == rhs.serverIdentifier,
              let lhsZone = lhs.decodedEventData?["zone"] as? String,
              let rhsZone = rhs.decodedEventData?["zone"] as? String else { return false }
        return lhsZone == rhsZone
    }

    private func save(_ events: [PendingZoneEvent]) {
        if events.isEmpty {
            defaults.removeObject(forKey: key)
        } else if let data = try? JSONEncoder().encode(events) {
            defaults.set(data, forKey: key)
        }
    }
}
