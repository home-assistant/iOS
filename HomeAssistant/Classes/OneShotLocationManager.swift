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

public class OneShotLocationManager: NSObject, CLLocationManagerDelegate {
    let locationManager = CLLocationManager()
    var onLocationUpdated: OnLocationUpdated

    public init(onLocation: @escaping OnLocationUpdated) {
        onLocationUpdated = onLocation
        super.init()
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = kCLLocationAccuracyHundredMeters
        locationManager.delegate = self
        locationManager.requestLocation()

        if let location = locationManager.location {
            Current.Log.verbose("LocationManager: Got location stored on manager \(location)")
            onLocationUpdated(location, nil)
            locationManager.delegate = nil
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Current.Log.verbose("LocationManager: Got \(locations.count) locations, stopping updates!")
        onLocationUpdated(locations.first, nil)
        manager.delegate = nil
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Current.Log.error("Received locationManager error \(error)")
        if let clErr = error as? CLError {
            let realm = Current.realm()
            // swiftlint:disable:next force_try
            try! realm.write {
                let locErr = LocationError(err: clErr)
                realm.add(locErr)
            }
            Current.Log.error("Received CLError: \(clErr)")
            if clErr.code == CLError.locationUnknown {
                // locationUnknown just means that GPS may be taking an extra moment, so don't throw an error.
                return
            }
            onLocationUpdated(nil, clErr)
        } else {
            Current.Log.error("Received non-CLError when we only expected CLError: \(error)")
            onLocationUpdated(nil, error)
        }
    }
}
