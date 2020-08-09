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
        self.action = .init(identifier: action.ID, display: action.Name)

        #if os(iOS)
        MaterialDesignIcons.register()

        let iconRect = CGRect(x: 0, y: 0, width: 64, height: 64)

        let iconData = UIKit.UIGraphicsImageRenderer(size: iconRect.size).pngData { _ in
            let imageRect = iconRect.insetBy(dx: 8, dy: 8)

            UIColor(hex: action.BackgroundColor).set()
            UIRectFill(iconRect)

            MaterialDesignIcons(named: action.IconName)
                .image(ofSize: imageRect.size, color: UIColor(hex: action.IconColor))
                .draw(in: imageRect)
        }

        let image = INImage(imageData: iconData)

        // this should be:
        //   setImage(image, forParameterNamed: \Self.action)
        // but this crashes at runtime, iOS 13 at least
        __setImage(image, forParameterNamed: "action")
        #endif
    }
}
