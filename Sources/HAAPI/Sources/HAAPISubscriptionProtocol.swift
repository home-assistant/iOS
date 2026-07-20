/// A websocket subscription command: after a successful `result`, the server streams
/// `{"id": N, "type": "event", "event": Event}` frames until unsubscribed.
public protocol HAAPISubscriptionProtocol: Sendable {
    associatedtype Event: Decodable & Sendable
    var command: String { get }
    var data: [String: HAAPIJSONValue] { get }
}
