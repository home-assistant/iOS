//
//  SendLocation.swift
//  SiriIntents
//
//  Created by Robert Trencheny on 9/17/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import Foundation
import UIKit
import CoreLocation
import Shared
import MapKit

class SendLocationIntentHandler: NSObject, SendLocationIntentHandling {
    func confirm(intent: SendLocationIntent, completion: @escaping (SendLocationIntentResponse) -> Void) {
        HomeAssistantAPI.authenticatedAPIPromise.catch { (error) in
            print("Can't get a authenticated API", error)
            completion(SendLocationIntentResponse(code: .failureConnectivity, userActivity: nil))
            return
        }

        // If location is already set, use that. If not...
        // Attempt to grab pasteboard contents and split by comma.
        // The hope is the user has something like LAT,LONG on the pasteboard
        // and we can use that for a CLLocation to update location with.
        // If they don't have a string like that then we assume they have a address on pasteboard.

        if let place = intent.location {
            self.completeConfirm(place: place, source: .stored, completion: completion)
            return
        } else if let pasteboardString = UIPasteboard.general.string {
            print("Pasteboard contains...", pasteboardString)
            let allowedLatLongChars = CharacterSet(charactersIn: "0123456789,-.")
            if pasteboardString.rangeOfCharacter(from: allowedLatLongChars.inverted) == nil {
                print("Appears we have a lat,long formatted string")
                let splitString = pasteboardString.components(separatedBy: ",")
                if let latitude = CLLocationDegrees(splitString[0]), let longitude = CLLocationDegrees(splitString[1]) {
                    let coord = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

                    if !CLLocationCoordinate2DIsValid(coord) {
                        print("Invalid coords!!")
                        completion(SendLocationIntentResponse(code: .failureClipboardNotParseable, userActivity: nil))
                        return
                    }

                    // We use MKPlacemark so we can return a CLPlacemark without requiring use of the geocoder
                    self.completeConfirm(place: MKPlacemark(coordinate: coord), source: .latlong,
                                         completion: completion)
                    return
                } else {
                    completion(SendLocationIntentResponse(code: .failureClipboardNotParseable, userActivity: nil))
                }
            } else { // Fallback to assuming that there's an address on there
                let geocoder = CLGeocoder()

                print("Not a lat,long, attempting geocode of string")
                geocoder.geocodeAddressString(pasteboardString) { (placemarks, error) in
                    if let error = error {
                        print("Error when geocoding string!", error)
                        completion(SendLocationIntentResponse(code: .failure, userActivity: nil))
                    }
                    if let placemarks = placemarks {
                        print("Got a placemark!", placemarks[0])
                        self.completeConfirm(place: placemarks.first, source: .address, completion: completion)
                    }
                }
            }
        } else {
            print("Nothing on Clipboard and a Placemark wasn't given, assuming user wants current location")
            completeConfirm(place: nil, source: .unknown, completion: completion)
        }
    }

    func handle(intent: SendLocationIntent, completion: @escaping (SendLocationIntentResponse) -> Void) {
        print("Handling send location")
        completion(SendLocationIntentResponse(code: .success, userActivity: nil))

        guard let api = HomeAssistantAPI.authenticatedAPI() else {
            completion(SendLocationIntentResponse(code: .failureConnectivity, userActivity: nil))
            return
        }

        api.submitLocation(updateType: LocationUpdateTrigger.Siri, location: intent.location?.location,
                           visit: nil, zone: nil).done {
                completion(SendLocationIntentResponse(code: .success, userActivity: nil))
            }.catch { error in
                print("Error sending location during Siri Shortcut call: \(error)")
                completion(SendLocationIntentResponse(code: .failure, userActivity: nil))
        }

    }

    func completeConfirm(place: CLPlacemark?, source: SendLocationClipboardLocationParsedAs,
                         completion: @escaping (SendLocationIntentResponse) -> Void) {
        print("Confirming send location as place", place, "which was derived via", source)

        let resp = SendLocationIntentResponse(code: .ready, userActivity: nil)
        resp.location = place
        resp.source = source

        completion(resp)
    }
}
