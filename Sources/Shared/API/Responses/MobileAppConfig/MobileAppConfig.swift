import Foundation
import ObjectMapper

public struct MobileAppConfig: ImmutableMappable {
    public var push: MobileAppConfigPush
    public var actions: [MobileAppConfigAction]

    init(push: MobileAppConfigPush = .init(), actions: [MobileAppConfigAction] = []) {
        self.push = push
        self.actions = actions
    }

    public init(map: Map) throws {
        self.push = (try? map.value("push")) ?? MobileAppConfigPush()
        self.actions = map.value("actions", default: [])
    }
}
