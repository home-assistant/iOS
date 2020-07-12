import Foundation

public typealias WebSocketEventHandler = (WebSocketEventRegistration, WebSocketEvent) -> Void

public struct WebSocketEventType: RawRepresentable, Hashable {
    public let rawValue: String
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static var callService: Self = .init(rawValue:"call_service")
    public static var componentLoaded: Self = .init(rawValue:"component_loaded")
    public static var coreConfigUpdated: Self = .init(rawValue:"core_config_updated")
    public static var homeassistantClose: Self = .init(rawValue:"homeassistant_close")
    public static var homeassistantStart: Self = .init(rawValue:"homeassistant_start")
    public static var homeassistantStarted: Self = .init(rawValue:"homeassistant_started")
    public static var homeassistantStop: Self = .init(rawValue:"homeassistant_stop")
    public static var homeassistantFinalWrite: Self = .init(rawValue:"homeassistant_final_write")
    public static var logbookEntry: Self = .init(rawValue:"logbook_entry")
    public static var platformDiscovered: Self = .init(rawValue:"platform_discovered")
    public static var serviceRegistered: Self = .init(rawValue:"service_registered")
    public static var serviceRemoved: Self = .init(rawValue:"service_removed")
    public static var stateChanged: Self = .init(rawValue:"state_changed")
    public static var themesUpdated: Self = .init(rawValue:"themes_updated")
    public static var timerOutOfSync: Self = .init(rawValue:"timer_out_of_sync")
    public static var timeChanged: Self = .init(rawValue:"time_changed")
}

public class WebSocketEventRegistration: Equatable {
    internal let type: WebSocketEventType?
    internal let handler: WebSocketEventHandler
    internal let uniqueID = UUID()
    internal var subscriptionIdentifier: WebSocketRequestIdentifier?

    internal init(type: WebSocketEventType?, handler: @escaping WebSocketEventHandler) {
        self.type = type
        self.handler = handler
    }

    internal func fire(_ event: WebSocketEvent) {
        handler(self, event)
    }

    public static func == (lhs: WebSocketEventRegistration, rhs: WebSocketEventRegistration) -> Bool {
        lhs.uniqueID == rhs.uniqueID
    }
}

public struct WebSocketEvent {
    public var eventType: WebSocketEventType
    public var firedAt: Date
    public var data: WebSocketData

    public enum Origin: String, Codable {
        case local = "LOCAL"
        case remote = "REMOTE"
    }

    public var origin: Origin

    enum CodingKeys: String, CodingKey {
        case eventType = "event_type"
        case firedAt = "time_fired"
        case data
        case origin
    }

    enum EventError: Error {
        case missingEventType
    }

    init(dictionary: [String: Any]) throws {
        guard let eventTypeRaw = dictionary["event_type"] as? String else {
            throw EventError.missingEventType
        }

        let firedAt = HomeAssistantTimestampTransform().transformFromJSON(dictionary["time_fired"]) ?? Current.date()
        let origin = (dictionary["origin"] as? String).flatMap { Origin(rawValue: $0) } ?? .local

        self.eventType = .init(rawValue: eventTypeRaw)
        self.firedAt = firedAt
        self.origin = origin
        self.data = WebSocketData(value: dictionary["data"])
    }
}
