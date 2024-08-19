import Foundation

public struct HAScene: Codable, Equatable {
    public static func cacheKey(serverId: String) -> String {
        "scenes-cache-\(serverId)"
    }

    public var id: String
    public var name: String?
    public var iconName: String?

    public init(id: String, name: String?, iconName: String?) {
        self.id = id
        self.name = name
        self.iconName = iconName
    }
}
