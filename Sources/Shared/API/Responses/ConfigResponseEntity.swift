import Foundation
import ObjectMapper

public struct ConfigResponseEntity: ImmutableMappable, Equatable {
    public let disabled: Bool

    public init(disabled: Bool) {
        self.disabled = disabled
    }

    public init(map: Map) throws {
        self.disabled = try map.value("disabled")
    }

    public func mapping(map: Map) {
        disabled >>> map["disabled"]
    }
}
