/// One row of a `config/area_registry/list` response.
public struct HAAPIArea: Decodable, Sendable, Equatable {
    public var areaId: String
    public var name: String
    public var picture: String?
    public var icon: String?
    public var aliases: [String]?
    public var floorId: String?

    enum CodingKeys: String, CodingKey {
        case areaId = "area_id"
        case name
        case picture
        case icon
        case aliases
        case floorId = "floor_id"
    }
}
