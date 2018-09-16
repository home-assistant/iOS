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

class OneShotLocationManager: NSObject {
    let locationManager = CLLocationManager()
    var onLocationUpdated: OnLocationUpdated

    init(onLocation: @escaping OnLocationUpdated) {
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
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        print("LocationManager: Got location, stopping updates!", locations.last.debugDescription, locations.count)
        onLocationUpdated(locations.first, nil)
        manager.stopUpdatingLocation()
        manager.delegate = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
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

    public func sendLocation(trigger: LocationUpdateTrigger?) -> Promise<Void> {
        var updateTrigger: LocationUpdateTrigger = .Manual
        if let trigger = trigger {
            updateTrigger = trigger
        }

        print("getAndSendLocation called via", String(describing: updateTrigger))

        return Promise { seal in
            regionManager.oneShotLocationActive = true
            oneShotLocationManager = OneShotLocationManager { location, error in
                guard let location = location else {
                    seal.reject(error ?? HomeAssistantAPIError.unknown)
                    return
                }

                self.regionManager.oneShotLocationActive = false
                firstly {
                    self.submitLocation(updateType: updateTrigger, location: location,
                                        visit: nil, zone: nil)
                    }.done { _ in
                        seal.fulfill(())
                    }.catch { error in
                        seal.reject(error)
                }
            }
        }
    }
}
