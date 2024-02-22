import Foundation
import ObjectMapper

public struct MobileAppConfigPush: ImmutableMappable {
    public var categories: [MobileAppConfigPushCategory]

    init(categories: [MobileAppConfigPushCategory] = []) {
        self.categories = []
    }

    public init(map: Map) throws {
        self.categories = map.value("categories", default: [])
    }
}
