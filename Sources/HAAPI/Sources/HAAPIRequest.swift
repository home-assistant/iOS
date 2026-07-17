/// Generic concrete request. Command factories live in `Commands/` as constrained extensions,
/// e.g. `HAAPIRequest<[HAAPIEntityState]>.getStates()`.
public struct HAAPIRequest<Response: Decodable & Sendable>: HAAPIRequestProtocol {
    public var command: String
    public var data: [String: HAAPIJSONValue]

    public init(command: String, data: [String: HAAPIJSONValue] = [:]) {
        self.command = command
        self.data = data
    }
}
