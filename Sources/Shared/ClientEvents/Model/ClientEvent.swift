import Foundation
import RealmSwift
import GRDB

public struct ClientEvent: Codable, FetchableRecord, PersistableRecord {
    public var id: String = UUID().uuidString
    public var text: String = ""
    public var type: EventType = .unknown
    public var jsonPayload: [String: AnyCodable] = [:]
    public var date: Date = Current.date()

    public enum EventType: String, Codable {
        case notification
        case serviceCall
        case locationUpdate
        case networkRequest
        case settings
        case unknown
    }

    private var jsonData: Data?

    public var jsonPayloadDescription: String? {
        jsonData.flatMap { String(data: $0, encoding: .utf8) }
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

        do {
            let writeOptions: JSONSerialization.WritingOptions = [.prettyPrinted, .withoutEscapingSlashes]
            jsonData = try JSONSerialization.data(withJSONObject: payload ?? [:], options: writeOptions)
        } catch {
            Current.Log.error("Error serializing json payload: \(error)")
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
}

public struct AnyCodable: Codable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable value cannot be decoded")
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
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: container.codingPath, debugDescription: "AnyCodable value cannot be encoded"))
        }
    }
}


///// Contains data about an event that occurred on the client, used for logging.
//public class ClientEvent: Object {
//    /// The type of event being logged.
//    public enum EventType: String {
//        case notification
//        case serviceCall
//        case locationUpdate
//        case networkRequest
//        case settings
//        case unknown
//    }
//
//    public convenience init(text: String, type: EventType, payload: [String: Any]? = nil) {
//        self.init()
//        self.text = text
//        self.type = type
//        self.jsonPayload = payload
//    }
//
//    /// The date the event occurred.
//    @objc public dynamic var date: Date = Current.date()
//
//    /// The text describing the event.
//    @objc public dynamic var text: String = ""
//    @objc private dynamic var typeString: String = EventType.unknown.rawValue
//
//    /// The even type
//    public var type: EventType {
//        get { EventType(rawValue: typeString) ?? .unknown }
//        set { typeString = newValue.rawValue }
//    }
//
//    @objc private dynamic var jsonData: Data?
//
//    /// The payload for the event.
//    public var jsonPayload: [String: Any]? {
//        get {
//            guard let payloadData = jsonData,
//                  let jsonObject = try? JSONSerialization.jsonObject(with: payloadData),
//                  let dictionary = jsonObject as? [String: Any] else {
//                return nil
//            }
//
//            return dictionary
//        }
//
//        set {
//            guard let payload = newValue else {
//                jsonData = nil
//                return
//            }
//
//            do {
//                let writeOptions: JSONSerialization.WritingOptions = [.prettyPrinted, .withoutEscapingSlashes]
//
//                jsonData = try JSONSerialization.data(withJSONObject: payload, options: writeOptions)
//            } catch {
//                Current.Log.error("Error serializing json payload: \(error)")
//            }
//        }
//    }
//
//    public var jsonPayloadDescription: String? {
//        jsonData.flatMap { String(data: $0, encoding: .utf8) }
//    }
//
//    override public static func indexedProperties() -> [String] {
//        ["date", "typeString"]
//    }
//}
