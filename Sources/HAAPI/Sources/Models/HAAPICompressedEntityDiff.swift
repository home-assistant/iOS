/// A changed entity in the compressed `subscribe_entities` format: `+` carries updated fields,
/// `-` lists removed attribute keys.
public struct HAAPICompressedEntityDiff: Decodable, Sendable, Equatable {
    public var additions: HAAPICompressedEntityUpdates?
    public var removals: Removals?

    enum CodingKeys: String, CodingKey {
        case additions = "+"
        case removals = "-"
    }

    public struct Removals: Decodable, Sendable, Equatable {
        public var attributes: [String]?

        enum CodingKeys: String, CodingKey {
            case attributes = "a"
        }
    }
}
