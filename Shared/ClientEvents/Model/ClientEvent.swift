//
//  ClientEvent.swift
//  HomeAssistant
//
//  Created by Stephan Vanterpool on 6/17/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import RealmSwift

public class ClientEvent: Object {
    public enum EventType: String {
        case notification
        case serviceCall
        case unknown
    }
    public static func eventWithText(_ text: String, type: EventType, payload: [String: Any]? = nil) -> ClientEvent {
        let event = ClientEvent()
        event.text = text
        event.type = type
        event.jsonPayload = payload
        return event
    }

    @objc public dynamic var date: Date = Current.date()
    @objc public dynamic var text: String = ""
    @objc private dynamic var typeString: String = EventType.unknown.rawValue
    public var type: EventType {
        get { return EventType(rawValue: self.typeString) ?? .unknown }
        set { self.typeString = newValue.rawValue }
    }

    @objc private dynamic var jsonData: Data?
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
