import Foundation
import HAKit

public struct LogbookEntry: HADataDecodable {
    public let entityId: String?
    public let when: Date
    public let domain: String?
    public let message: String?
    public let state: String?
    public let name: String?
    public let iconName: String?

    public init(data: HAData) throws {
        self.when = try data.decode("when")
        self.entityId = data.decode("entity_id", fallback: nil)
        self.domain = data.decode("domain", fallback: nil)
        self.message = data.decode("message", fallback: nil)
        self.state = data.decode("state", fallback: nil)
        self.name = data.decode("name", fallback: nil)
        self.iconName = data.decode("icon", fallback: nil)
    }
}
