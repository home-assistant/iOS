import Foundation

struct PendingZoneEvent: Codable, Equatable {
    enum PayloadError: Error {
        case invalidJSONObject
    }

    let id: UUID
    let serverIdentifier: String
    let eventType: String
    let eventData: Data
    let createdAt: Date
    let isBeacon: Bool?
    var deliveryStartedAt: Date?

    init(
        id: UUID = UUID(),
        serverIdentifier: String,
        eventType: String,
        eventData: [String: Any],
        createdAt: Date = Date(),
        isBeacon: Bool = false,
        deliveryStartedAt: Date? = nil
    ) throws {
        // Invalid Foundation objects raise an Objective-C exception, not a Swift error.
        guard JSONSerialization.isValidJSONObject(eventData) else {
            throw PayloadError.invalidJSONObject
        }
        self.id = id
        self.serverIdentifier = serverIdentifier
        self.eventType = eventType
        self.eventData = try JSONSerialization.data(withJSONObject: eventData, options: [.sortedKeys])
        self.createdAt = createdAt
        self.isBeacon = isBeacon
        self.deliveryStartedAt = deliveryStartedAt
    }

    var decodedEventData: [String: Any]? {
        (try? JSONSerialization.jsonObject(with: eventData)) as? [String: Any]
    }
}
