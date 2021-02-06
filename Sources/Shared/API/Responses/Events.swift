import Foundation
import ObjectMapper

public class EventsResponse: Mappable {
    public var Event: String?
    public var ListenerCount: Int?

    public required init?(map: Map) {}

    public func mapping(map: Map) {
        Event <- map["event"]
        ListenerCount <- map["listener_count"]
    }
}
