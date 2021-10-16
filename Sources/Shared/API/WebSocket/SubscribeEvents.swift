import Foundation

class SubscribeEvents: WebSocketMessage {
    public var EventType: String = ""

    private enum CodingKeys: String, CodingKey {
        case EventType = "event_type"
    }

    init(eventType: String) {
        super.init("subscribe_events")
        self.EventType = eventType
    }

    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let superdecoder = try values.superDecoder()
        try super.init(from: superdecoder)

        self.EventType = try values.decode(String.self, forKey: .EventType)
    }

    override public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(EventType, forKey: .EventType)

        try super.encode(to: encoder)
    }
}
