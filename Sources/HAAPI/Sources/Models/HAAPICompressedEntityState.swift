import Foundation

/// A full entity state in the compressed `subscribe_entities` format. Dates arrive as epoch
/// seconds; `c` (context) can be a bare id string or an object, hence the JSON value type.
public struct HAAPICompressedEntityState: Decodable, Sendable, Equatable {
    public var state: String
    public var attributes: [String: HAAPIJSONValue]?
    public var context: HAAPIJSONValue?
    public var lastChanged: Date?
    public var lastUpdated: Date?

    enum CodingKeys: String, CodingKey {
        case state = "s"
        case attributes = "a"
        case context = "c"
        case lastChanged = "lc"
        case lastUpdated = "lu"
    }
}
