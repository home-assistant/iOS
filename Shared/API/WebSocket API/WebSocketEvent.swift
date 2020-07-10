import Foundation

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

public struct WebSocketEventRegistration {
    internal let identifier: WebSocketRequestIdentifier
    private weak var api: WebSocketAPI?

    internal init(identifier: WebSocketRequestIdentifier, api: WebSocketAPI) {
        self.identifier = identifier
        self.api = api
    }

    func unsubscribe() {
        api?.unsubscribe(self)
    }
}

public struct WebSocketEvent {
    internal var registration: WebSocketEventRegistration

    public var eventType: WebSocketEventType
    public var firedAt: Date
    public var data: WebSocketData

    public enum Origin: String {
        case local = "LOCAL"
        case remote = "REMOTE"
    }

    public var origin: Origin

    init?(registration: WebSocketEventRegistration, dictionary: [String: Any]) {
        guard let eventTypeRaw = dictionary["event_type"] as? String else {
            return nil
        }

        guard let firedAt = HomeAssistantTimestampTransform().transformFromJSON(dictionary["time_fired"]) else {
            return nil
        }

        guard let originRaw = dictionary["origin"] as? String, let origin = Origin(rawValue: originRaw) else {
            return nil
        }

        self.registration = registration
        self.eventType = .init(rawValue: eventTypeRaw)
        self.firedAt = firedAt
        self.origin = origin
        self.data = WebSocketData(value: dictionary["data"])
    }
}
