import Foundation

public enum WebSocketData {
    case dictionary([String: Any])
    case array([Any])
    case empty

    init(value: Any?) {
        if let value = value as? [String: Any] {
            self = .dictionary(value)
        } else if let value = value as? [Any] {
            self = .array(value)
        } else {
            self = .empty
        }
    }
}
