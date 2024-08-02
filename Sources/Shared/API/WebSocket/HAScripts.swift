import Foundation

public struct HAScript: Codable, Equatable {
    public static func cacheKey(serverId: String) -> String {
        "scripts-cache-\(serverId)"
    }

    public var id: String
    public var name: String?

    public init(id: String, name: String?) {
        self.id = id
        self.name = name
    }
}
