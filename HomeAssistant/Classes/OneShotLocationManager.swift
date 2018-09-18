//
//  LocationManager.swift
//  HomeAssistant
//
//  Created by Stephan Vanterpool on 8/24/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import CoreLocation
import Foundation
import PromiseKit

public typealias OnLocationUpdated = ((CLLocation?, Error?) -> Void)

public class OneShotLocationManager: NSObject {
    let locationManager = CLLocationManager()
    var onLocationUpdated: OnLocationUpdated
    public var waitingForLocation = false

    public init(onLocation: @escaping OnLocationUpdated) {
        onLocationUpdated = onLocation
        super.init()
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.distanceFilter = kCLLocationAccuracyHundredMeters
        locationManager.delegate = self
        locationManager.startUpdatingLocation()
    }
}

extension OneShotLocationManager: CLLocationManagerDelegate {
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        print("LocationManager: Got location, stopping updates!", locations.last.debugDescription, locations.count)
        onLocationUpdated(locations.first, nil)
        manager.stopUpdatingLocation()
        manager.delegate = nil
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let clErr = error as? CLError {
            let realm = Current.realm()
            // swiftlint:disable:next force_try
            try! realm.write {
                let locErr = LocationError(err: clErr)
                realm.add(locErr)
            }
            print("Received CLError:", clErr.debugDescription)
            if clErr.code == CLError.locationUnknown {
                // locationUnknown just means that GPS may be taking an extra moment, so don't throw an error.
                return
            }
            onLocationUpdated(nil, clErr)
        } else {
            print("Received non-CLError when we only expected CLError:", error.localizedDescription)
            onLocationUpdated(nil, error)
        }
    }
}
