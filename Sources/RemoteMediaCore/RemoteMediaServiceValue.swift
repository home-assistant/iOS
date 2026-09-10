import Foundation

/// The value types a `media_player` service call needs, kept concrete so payloads stay `Equatable`
/// and testable rather than being `[String: Any]` all the way down.
public enum RemoteMediaServiceValue: Equatable, Sendable {
    case string(String)
    case number(Double)

    public var jsonValue: Any {
        switch self {
        case let .string(value): return value
        case let .number(value): return value
        }
    }
}
