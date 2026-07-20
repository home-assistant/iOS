/// Generic concrete subscription. Factories live in `Commands/` as constrained extensions,
/// e.g. `HAAPISubscription<HAAPICompressedStatesUpdate>.subscribeEntities()`.
public struct HAAPISubscription<Event: Decodable & Sendable>: HAAPISubscriptionProtocol {
    public var command: String
    public var data: [String: HAAPIJSONValue]

    public init(command: String, data: [String: HAAPIJSONValue] = [:]) {
        self.command = command
        self.data = data
    }
}
