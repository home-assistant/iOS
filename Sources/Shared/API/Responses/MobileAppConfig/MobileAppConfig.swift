import Foundation
import ObjectMapper

public struct MobileAppConfig: ImmutableMappable {
    public var push: MobileAppConfigPush

    init(push: MobileAppConfigPush = .init()) {
        self.push = push
    }

    public init(map: Map) throws {
        self.push = (try? map.value("push")) ?? MobileAppConfigPush()
    }
}
