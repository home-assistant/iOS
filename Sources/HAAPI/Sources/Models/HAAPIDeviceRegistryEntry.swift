/// One row of a `config/device_registry/list` response (only the fields the apps consume).
public struct HAAPIDeviceRegistryEntry: Decodable, Sendable, Equatable {
    public var id: String
    public var areaId: String?
    public var name: String?
    public var nameByUser: String?

    enum CodingKeys: String, CodingKey {
        case id
        case areaId = "area_id"
        case name
        case nameByUser = "name_by_user"
    }
}
