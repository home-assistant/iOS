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

class SendLocationIntentHandler: NSObject, SendLocationIntentHandling {
    func confirm(intent: SendLocationIntent, completion: @escaping (SendLocationIntentResponse) -> Void) {
        // TODO: Ensure we can contact Home Assistant, token is valid, etc, here. Otherwise, throw a failure NOW.

        // Attempt to grab pasteboard contents and split by command.
        // The hope is the user has something like LAT,LONG on the pasteboard
        // and we can use that for a CLLocation to update location with.
        // If they don't have a string like that then we assume they have a address on pasteboard.

        let geocoder = CLGeocoder()

        if let pasteboardString = UIPasteboard.general.string {
            print("Pasteboard contains...", pasteboardString)
            let allowedLatLongChars = CharacterSet(charactersIn: "0123456789,-.")
            if pasteboardString.rangeOfCharacter(from: allowedLatLongChars.inverted) == nil {
                print("Appears we have a lat,long formatted string")
                let splitString = pasteboardString.components(separatedBy: ",")
                if let latitude = CLLocationDegrees(splitString[0]), let longitude = CLLocationDegrees(splitString[1]) {
                    if !CLLocationCoordinate2DIsValid(CLLocationCoordinate2D(latitude: latitude,
                                                                             longitude: longitude)) {
                        print("Invalid coords!!")
                        completion(SendLocationIntentResponse(code: .failureClipboardNotParseable, userActivity: nil))
                        return
                    }
                    geocoder.reverseGeocodeLocation(CLLocation(latitude: latitude, longitude: longitude)) {
                        (placemarks, error) in
                        if let error = error {
                            print("Error when reverse geocoding LAT,LNG!", error)
                            completion(SendLocationIntentResponse(code: .failureClipboardNotParseable,
                                                                  userActivity: nil))
                        }
                        if let placemarks = placemarks {
                            print("Got a placemark!", placemarks[0])
                            self.completeConfirm(place: placemarks.first, source: .latlong, completion: completion)
                        }
                    }
                }
            } else { // Fallback to assuming that there's an address on there
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
            print("Nothing on Clipboard, assuming user wants current location")
            completeConfirm(place: nil, source: .unknown, completion: completion)
        }
    }

    func handle(intent: SendLocationIntent, completion: @escaping (SendLocationIntentResponse) -> Void) {
        print("Handling send location")
        completion(SendLocationIntentResponse(code: .success, userActivity: nil))
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
