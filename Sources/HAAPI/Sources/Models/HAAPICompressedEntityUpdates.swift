import Foundation

/// The `+` side of a compressed entity diff — every field optional because only what changed is
/// sent.
public struct HAAPICompressedEntityUpdates: Decodable, Sendable, Equatable {
    public var state: String?
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
