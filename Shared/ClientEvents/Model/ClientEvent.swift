//
//  ClientEvent.swift
//  HomeAssistant
//
//  Created by Stephan Vanterpool on 6/17/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import RealmSwift

/// Contains data about an event that occured on the client, used for logging.
public class ClientEvent: Object {
    /// The type of event being logged.
    public enum EventType: String {
        case notification
        case serviceCall
        case locationUpdate
        case networkRequest
        case unknown
    }

    convenience public init(text: String, type: EventType, payload: [String: Any]? = nil) {
        self.init()
        self.text = text
        self.type = type
        self.jsonPayload = payload
    }

    /// The date the event occured.
    @objc public dynamic var date: Date = Current.date()

    /// The text describing the event.
    @objc public dynamic var text: String = ""
    @objc private dynamic var typeString: String = EventType.unknown.rawValue

    /// The even type
    public var type: EventType {
        get { return EventType(rawValue: self.typeString) ?? .unknown }
        set { self.typeString = newValue.rawValue }
    }

    @objc private dynamic var jsonData: Data?

    /// The payload for the event.
    public var jsonPayload: [String: Any]? {
        set {
            guard let payload = newValue else {
                self.jsonData = nil
                return
            }

            do {
                jsonData = try JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted)
            } catch {
                print("Error serializing json payload: \(error)")
            }
        }

        get {
            guard let payloadData = self.jsonData,
            let jsonObject = try? JSONSerialization.jsonObject(with: payloadData),
            let dictionary = jsonObject as? [String: Any] else {
                return nil
            }

            return dictionary
        }
    }

    override public static func indexedProperties() -> [String] {
        return ["date", "typeString"]
    }
}
