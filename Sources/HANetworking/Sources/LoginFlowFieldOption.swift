import Foundation

/// One choice of a `select` login-flow field, serialized by the server as a `[value, label]` pair
/// (trusted networks lists the users to log in as this way).
public struct LoginFlowFieldOption: Decodable, Equatable, Hashable {
    public let value: String
    public let label: String

    public init(value: String, label: String) {
        self.value = value
        self.label = label
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        self.value = try container.decode(String.self)
        self.label = try container.decodeIfPresent(String.self) ?? value
    }
}
