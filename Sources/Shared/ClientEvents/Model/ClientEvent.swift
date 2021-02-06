import Foundation
import RealmSwift

/// Contains data about an event that occurred on the client, used for logging.
public class ClientEvent: Object {
    /// The type of event being logged.
    public enum EventType: String {
        case notification
        case serviceCall
        case locationUpdate
        case networkRequest
        case unknown
    }

    public convenience init(text: String, type: EventType, payload: [String: Any]? = nil) {
        self.init()
        self.text = text
        self.type = type
        self.jsonPayload = payload
    }

    /// The date the event occurred.
    @objc public dynamic var date: Date = Current.date()

    /// The text describing the event.
    @objc public dynamic var text: String = ""
    @objc private dynamic var typeString: String = EventType.unknown.rawValue

    /// The even type
    public var type: EventType {
        get { EventType(rawValue: typeString) ?? .unknown }
        set { typeString = newValue.rawValue }
    }

    @objc private dynamic var jsonData: Data?

    /// The payload for the event.
    public var jsonPayload: [String: Any]? {
        get {
            guard let payloadData = jsonData,
                  let jsonObject = try? JSONSerialization.jsonObject(with: payloadData),
                  let dictionary = jsonObject as? [String: Any] else {
                return nil
            }

            return dictionary
        }

        set {
            guard let payload = newValue else {
                jsonData = nil
                return
            }

            do {
                var writeOptions: JSONSerialization.WritingOptions = [.prettyPrinted]

                if #available(iOS 13, watchOS 6, *) {
                    writeOptions.insert(.withoutEscapingSlashes)
                }

                jsonData = try JSONSerialization.data(withJSONObject: payload, options: writeOptions)
            } catch {
                Current.Log.error("Error serializing json payload: \(error)")
            }
        }
    }

    public var jsonPayloadDescription: String? {
        jsonData.flatMap { String(data: $0, encoding: .utf8) }
    }

    override public static func indexedProperties() -> [String] {
        ["date", "typeString"]
    }
}
