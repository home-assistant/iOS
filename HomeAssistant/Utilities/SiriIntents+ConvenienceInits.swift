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

extension CallServiceIntent {
    convenience init(domain: String, service: String, description: String?) {
        self.init()
        self.serviceDomain = domain
        self.service = service
        self.serviceDescription = description
    }

    convenience init(domain: String, service: String, payload: Any?) {
        self.init()
        self.serviceDomain = domain
        self.service = service

        if let payload = payload, let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: []),
            let jsonString = String(data: jsonData, encoding: .utf8) {
            self.payload = jsonString
        }
    }
}

extension FireEventIntent {
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

extension SendLocationIntent {
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
