import Foundation
import ObjectMapper

public struct MobileAppConfig: ImmutableMappable {
    public var push: MobileAppConfigPush
    public var actions: [MobileAppConfigAction]
    public var carPlay: CarPlayConfiguration

    init(push: MobileAppConfigPush = .init(), actions: [MobileAppConfigAction] = [], carPlay: CarPlayConfiguration =  CarPlayConfiguration(enabled: true, quickAccess: [])) {
        self.push = push
        self.actions = actions
        self.carPlay = carPlay
    }

    public init(map: Map) throws {
        self.push = (try? map.value("push")) ?? MobileAppConfigPush()
        self.actions = map.value("actions", default: [])
        self.carPlay = (try? map.value("carplay")) ?? CarPlayConfiguration(enabled: true, quickAccess: [])
    }

    public struct CarPlayConfiguration: ImmutableMappable {
        public let enabled: Bool
        public let quickAccess: [QuickAccessItem]

        init(enabled: Bool = false, quickAccess: [QuickAccessItem] = []) {
            self.enabled = enabled
            self.quickAccess = quickAccess
        }

        public init(map: Map) throws {
            self.enabled = try map.value("enabled")
            self.quickAccess = (try? map.value("quick_access")) ?? []
        }

        public struct QuickAccessItem: ImmutableMappable {
            public let entityId: String
            public let displayName: String?

            public init(map: Map) throws {
                self.entityId = try map.value("entity_id")
                self.displayName = try? map.value("display_name")
            }
        }
    }
}
