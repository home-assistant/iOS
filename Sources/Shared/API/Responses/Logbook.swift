import Foundation
import ObjectMapper

public class LogbookResponse: Mappable {
    public var Domain: String?
    public var EntityId: String?
    public var Message: String?
    public var State: String?
    public var Name: String?
    public var When: Date?
    public var IconName: String?

    public required init?(map: Map) {}

    public func mapping(map: Map) {
        Domain <- map["domain"]
        EntityId <- map["entity_id"]
        Message <- map["message"]
        State <- map["state"]
        Name <- map["name"]
        IconName <- map["icon"]
        When <- (map["when"], HomeAssistantTimestampTransform())
    }
}
