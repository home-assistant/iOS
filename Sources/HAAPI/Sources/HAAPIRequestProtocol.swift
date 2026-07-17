/// A websocket command with a typed result (`{"id": N, "type": command, ...data}` →
/// `{"id": N, "type": "result", "result": Response}`).
public protocol HAAPIRequestProtocol: Sendable {
    associatedtype Response: Decodable & Sendable
    var command: String { get }
    var data: [String: HAAPIJSONValue] { get }
}
