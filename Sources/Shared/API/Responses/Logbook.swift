import Foundation
import ObjectMapper

public class LogbookResponse: Mappable {
    public var domain: String?
    public var entityId: String?
    public var message: String?
    public var state: String?
    public var name: String?
    public var when: Date?
    public var iconName: String?

    public required init?(map: Map) {}

    public func mapping(map: Map) {
        domain <- map["domain"]
        entityId <- map["entity_id"]
        message <- map["message"]
        state <- map["state"]
        name <- map["name"]
        iconName <- map["icon"]
        when <- (map["when"], HomeAssistantTimestampTransform())
    }
}
