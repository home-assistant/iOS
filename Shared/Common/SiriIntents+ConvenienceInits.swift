//
//  SiriIntents+ConvenienceInits.swift
//  HomeAssistant
//
//  Created by Robert Trencheny on 9/19/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import CoreLocation
import MapKit
import Intents
import UIColor_Hex_Swift

@available(iOS 12, *)
public extension CallServiceIntent {
    convenience init(domain: String, service: String) {
        self.init()
        self.service = "\(domain).\(service)"
    }

    convenience init(domain: String, service: String, payload: Any?) {
        self.init()
        self.service = "\(domain).\(service)"

        if let payload = payload, let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: []),
            let jsonString = String(data: jsonData, encoding: .utf8) {
            self.payload = jsonString
        }
    }
}

@available(iOS 12, *)
public extension FireEventIntent {
    convenience init(eventName: String) {
        self.init()
        self.eventName = eventName
    }

    convenience init(eventName: String, payload: Any?) {
        self.init()
        self.eventName = eventName

        if let payload = payload, let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: []),
            let jsonString = String(data: jsonData, encoding: .utf8) {
            self.eventData = jsonString
        }
    }
}

@available(iOS 12, *)
public extension SendLocationIntent {
    convenience init(place: CLPlacemark) {
        self.init()
        self.location = place
    }

    convenience init(location: CLLocation) {
        self.init()

        // We use MKPlacemark so we can return a CLPlacemark without requiring use of the geocoder
        self.location = MKPlacemark(coordinate: location.coordinate)
    }
}

@available(iOS 12, *)
public extension PerformActionIntent {
    convenience init(action: Action) {
        self.init()
        self.action = .init(action: action)

        #if os(iOS)
        let image = INImage(
            icon: MaterialDesignIcons(named: action.IconName),
            foreground: UIColor(hex: action.IconColor),
            background: UIColor(hex: action.BackgroundColor)
        )

        // this should be:
        //   setImage(image, forParameterNamed: \Self.action)
        // but this crashes at runtime, iOS 13 and iOS 14 at least
        __setImage(image, forParameterNamed: "action")
        #endif
    }
}

@available(iOS 12, *)
extension IntentAction {
    public convenience init(action: Action) {
        #if os(iOS)
            if #available(iOS 14, *) {
                self.init(
                    identifier: action.ID,
                    display: action.Name,
                    subtitle: nil,
                    image: INImage(
                        icon: MaterialDesignIcons(named: action.IconName),
                        foreground: UIColor(hex: action.IconColor),
                        background: UIColor(hex: action.BackgroundColor)
                    )
                )
            } else {
                self.init(identifier: action.ID, display: action.Name)
            }
        #else
            self.init(identifier: action.ID, display: action.Name)
        #endif
    }

    public func asActionWithUpdated() -> (updated: IntentAction, action: Action)? {
        guard let action = asAction() else {
            return nil
        }

        return (.init(action: action), action)
    }

    public func asAction() -> Action? {
        guard let identifier = identifier, identifier.isEmpty == false else {
            return nil
        }

        guard let result = Current.realm().object(ofType: Action.self, forPrimaryKey: identifier) else {
            return nil
        }

        return result
    }
}

@available(iOS 12, *)
extension WidgetActionsIntent {
    public static let widgetKind = "WidgetActions"
}
