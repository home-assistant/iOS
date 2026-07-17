/// One row of a `config/floor_registry/list` response.
public struct HAAPIFloor: Decodable, Sendable, Equatable {
    public var floorId: String
    public var name: String
    public var level: Int?
    public var icon: String?

    enum CodingKeys: String, CodingKey {
        case floorId = "floor_id"
        case name
        case level
        case icon
    }
}
