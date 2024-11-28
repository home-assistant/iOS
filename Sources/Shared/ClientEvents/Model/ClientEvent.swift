import Foundation
import GRDB

public struct ClientEvent: Codable, FetchableRecord, PersistableRecord {
    public var id: String = UUID().uuidString
    public var text: String = ""
    public var type: EventType = .unknown
    public var jsonPayload: [String: AnyCodable] = [:]
    public var date: Date = Current.date()

    public enum EventType: String, Codable, CaseIterable {
        case notification
        case serviceCall
        case locationUpdate
        case networkRequest
        case settings
        case database
        case unknown
    }

    public var jsonPayloadDescription: String? {
        jsonData().flatMap { String(data: $0, encoding: .utf8) }
    }

    public init(
        text: String,
        type: EventType,
        payload: [String: Any]? = [:],
        date: Date = Current.date()
    ) {
        self.text = text
        self.type = type
        self.jsonPayload = ClientEvent.convertToAnyCodable(payload ?? [:])
    }

    private func jsonData() -> Data? {
        do {
            let writeOptions: JSONSerialization.WritingOptions = [.prettyPrinted, .withoutEscapingSlashes]
            return try JSONSerialization.data(withJSONObject: jsonPayloadJSONObject(), options: writeOptions)
        } catch {
            Current.Log.error("Error serializing json payload: \(error)")
            return nil
        }
    }

    static func convertToAnyCodable(_ dictionary: [String: Any]) -> [String: AnyCodable] {
        var newDictionary: [String: AnyCodable] = [:]
        for (key, value) in dictionary {
            if let value = value as? [String: Any] {
                newDictionary[key] = AnyCodable(value)
            } else {
                newDictionary[key] = AnyCodable(value)
            }
        }
        return newDictionary
    }

    public func jsonPayloadJSONObject() -> [String: Any] {
        var newDictionary: [String: Any] = [:]
        for (key, value) in jsonPayload {
            newDictionary[key] = value.value
        }
        return newDictionary
    }
}

public struct AnyCodable: Codable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map(\.value)
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "AnyCodable value cannot be decoded"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map(AnyCodable.init))
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues(AnyCodable.init))
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "AnyCodable value cannot be encoded"
                )
            )
        }
    }
}

public extension ClientEvent.EventType {
    var displayText: String {
        switch self {
        case .notification:
            return L10n.ClientEvents.EventType.notification
        case .locationUpdate:
            return L10n.ClientEvents.EventType.locationUpdate
        case .serviceCall:
            return L10n.ClientEvents.EventType.serviceCall
        case .networkRequest:
            return L10n.ClientEvents.EventType.networkRequest
        case .unknown:
            return L10n.ClientEvents.EventType.unknown
        case .settings:
            return L10n.ClientEvents.EventType.settings
        case .database:
            return L10n.ClientEvents.EventType.database
        }
    }
}
