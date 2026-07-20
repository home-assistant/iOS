/// One `subscribe_entities` event in the compressed format: `a` add (full states), `r` remove
/// (entity ids), `c` change (diffs).
public struct HAAPICompressedStatesUpdate: Decodable, Sendable, Equatable {
    public var add: [String: HAAPICompressedEntityState]?
    public var remove: [String]?
    public var change: [String: HAAPICompressedEntityDiff]?

    enum CodingKeys: String, CodingKey {
        case add = "a"
        case remove = "r"
        case change = "c"
    }
}
