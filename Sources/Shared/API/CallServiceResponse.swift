import Foundation
import HAKit

/// Response of a websocket `call_service` performed with `return_response: true`.
///
/// Home Assistant returns `{ "context": { ... }, "response": <any> }` for actions that support a
/// response (`SupportsResponse.OPTIONAL` / `.ONLY`). The shape of `response` depends on the action,
/// so the raw value is kept untyped and can be JSON-serialized by callers.
public struct CallServiceResponse: HADataDecodable {
    /// The raw `response` value returned by the action, if any.
    public let response: Any?

    public init(data: HAData) throws {
        if case let .dictionary(dictionary) = data {
            self.response = dictionary["response"]
        } else {
            self.response = nil
        }
    }

    /// Whether the action returned a non-empty response value.
    public var hasResponse: Bool {
        switch response {
        case nil, is NSNull:
            return false
        case let dictionary as [String: Any]:
            return dictionary.isEmpty == false
        case let array as [Any]:
            return array.isEmpty == false
        default:
            return true
        }
    }

    /// The `response` value serialized as a JSON string, or nil when there is nothing to serialize.
    public func jsonString() -> String? {
        guard let response, !(response is NSNull) else { return nil }

        // Wrap primitives so JSONSerialization (which requires a top-level container) can encode them.
        let serializable: Any = (response is [String: Any] || response is [Any]) ? response : ["response": response]
        guard JSONSerialization.isValidJSONObject(serializable),
              let data = try? JSONSerialization.data(withJSONObject: serializable, options: [.sortedKeys]),
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        return string
    }
}
