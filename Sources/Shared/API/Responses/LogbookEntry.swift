import Foundation
import ObjectMapper

public struct LogbookEntry: ImmutableMappable {
    public let entityId: String
    public let when: Date
    public let domain: String?
    public let message: String?
    public let state: String?
    public let name: String?
    public let iconName: String?

    public init(map: Map) throws {
        self.entityId = try map.value("entity_id")
        self.when = try map.value("when", using: HomeAssistantTimestampTransform())
        self.domain = try? map.value("domain")
        self.message = try? map.value("message")
        self.state = try? map.value("state")
        self.name = try? map.value("name")
        self.iconName = try? map.value("icon")
    }
}
