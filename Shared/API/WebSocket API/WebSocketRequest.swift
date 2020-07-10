import Foundation

public struct WebSocketRequestType: RawRepresentable, Hashable {
    public let rawValue: String
    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static var subscribeEvents: Self = .init(rawValue: "subscribe_events")
    public static var unsubscribeEvents: Self = .init(rawValue: "unsubscribe_events")
    public static var callService: Self = .init(rawValue: "call_service")
    public static var getStates: Self = .init(rawValue: "get_states")
    public static var getConfig: Self = .init(rawValue: "get_config")
    public static var getServices: Self = .init(rawValue: "get_services")
    public static var getPanels: Self = .init(rawValue: "get_panels")
    public static var ping: Self = .init(rawValue: "ping")
}

public struct WebSocketRequest {
    public  var type: WebSocketRequestType
    public var data: [String: Any] // top-level
}
