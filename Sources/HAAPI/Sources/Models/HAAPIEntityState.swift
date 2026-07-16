import Foundation

/// One row of a `get_states` response.
public struct HAAPIEntityState: Decodable, Sendable, Equatable {
    public var entityId: String
    public var state: String
    public var attributes: [String: HAAPIJSONValue]
    public var lastChanged: Date?
    public var lastUpdated: Date?

    enum CodingKeys: String, CodingKey {
        case entityId = "entity_id"
        case state
        case attributes
        case lastChanged = "last_changed"
        case lastUpdated = "last_updated"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.entityId = try container.decode(String.self, forKey: .entityId)
        self.state = try container.decode(String.self, forKey: .state)
        self.attributes = try container.decodeIfPresent([String: HAAPIJSONValue].self, forKey: .attributes) ?? [:]
        self.lastChanged = try container.decodeIfPresent(Date.self, forKey: .lastChanged)
        self.lastUpdated = try container.decodeIfPresent(Date.self, forKey: .lastUpdated)
    }

    public init(
        entityId: String,
        state: String,
        attributes: [String: HAAPIJSONValue] = [:],
        lastChanged: Date? = nil,
        lastUpdated: Date? = nil
    ) {
        self.entityId = entityId
        self.state = state
        self.attributes = attributes
        self.lastChanged = lastChanged
        self.lastUpdated = lastUpdated
    }

    /// The part before the first `.` of the entity id.
    public var domain: String {
        String(entityId.prefix(while: { $0 != "." }))
    }
}
