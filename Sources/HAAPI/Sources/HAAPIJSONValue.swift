import Foundation

/// A JSON value that is fully `Sendable`, unlike `[String: Any]`-based approaches (e.g. HAKit's
/// `HAData`), so it can safely cross actor boundaries under strict concurrency. Used for request
/// payloads, dynamic attributes, and the untyped request/subscription variants.
public indirect enum HAAPIJSONValue: Sendable, Equatable, Hashable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([HAAPIJSONValue])
    case object([String: HAAPIJSONValue])
}

extension HAAPIJSONValue: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let array = try? container.decode([HAAPIJSONValue].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: HAAPIJSONValue].self) {
            self = .object(object)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Value is not a supported JSON type"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case let .bool(value):
            try container.encode(value)
        case let .int(value):
            try container.encode(value)
        case let .double(value):
            try container.encode(value)
        case let .string(value):
            try container.encode(value)
        case let .array(value):
            try container.encode(value)
        case let .object(value):
            try container.encode(value)
        }
    }
}

extension HAAPIJSONValue: ExpressibleByNilLiteral, ExpressibleByBooleanLiteral, ExpressibleByIntegerLiteral,
    ExpressibleByFloatLiteral, ExpressibleByStringLiteral, ExpressibleByArrayLiteral,
    ExpressibleByDictionaryLiteral {
    public init(nilLiteral: ()) { self = .null }
    public init(booleanLiteral value: Bool) { self = .bool(value) }
    public init(integerLiteral value: Int) { self = .int(value) }
    public init(floatLiteral value: Double) { self = .double(value) }
    public init(stringLiteral value: String) { self = .string(value) }
    public init(arrayLiteral elements: HAAPIJSONValue...) { self = .array(elements) }
    public init(dictionaryLiteral elements: (String, HAAPIJSONValue)...) {
        self = .object(.init(uniqueKeysWithValues: elements))
    }
}

public extension HAAPIJSONValue {
    /// Foundation representation, for bridging into legacy `Any`-based decoders such as HAKit's
    /// `HAData(value:)`. Numbers and bools are `NSNumber` (and null is `NSNull`) to match
    /// `JSONSerialization` output exactly: those decoders rely on `NSNumber`'s `as?` bridging,
    /// where a whole-number value casts to `Double` too — a Swift `Int` would not.
    var anyValue: Any {
        switch self {
        case .null: NSNull()
        case let .bool(value): NSNumber(value: value)
        case let .int(value): NSNumber(value: value)
        case let .double(value): NSNumber(value: value)
        case let .string(value): value
        case let .array(values): values.map(\.anyValue)
        case let .object(values): values.mapValues(\.anyValue)
        }
    }

    var stringValue: String? {
        if case let .string(value) = self { value } else { nil }
    }

    var boolValue: Bool? {
        if case let .bool(value) = self { value } else { nil }
    }

    var intValue: Int? {
        switch self {
        case let .int(value): value
        case let .double(value): Int(exactly: value)
        default: nil
        }
    }

    var doubleValue: Double? {
        switch self {
        case let .double(value): value
        case let .int(value): Double(value)
        default: nil
        }
    }

    var arrayValue: [HAAPIJSONValue]? {
        if case let .array(values) = self { values } else { nil }
    }

    var objectValue: [String: HAAPIJSONValue]? {
        if case let .object(values) = self { values } else { nil }
    }
}
