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
        guard HomeAssistantAPI.authenticatedAPI() != nil else {
            print("Can't get a authenticated API")
            completion(SendLocationIntentResponse(code: .failureConnectivity, userActivity: nil))
            return
        }

        parseForLocation(intent: intent, completion: completion)
    }

    func handle(intent: SendLocationIntent, completion: @escaping (SendLocationIntentResponse) -> Void) {
        print("Handling send location")

        guard let api = HomeAssistantAPI.authenticatedAPI() else {
            print("Failed to get Home Assistant API during handle of sendLocation")
            completion(SendLocationIntentResponse(code: .failureConnectivity, userActivity: nil))
            return
        }

        parseForLocation(intent: intent) { (resp) in
            if resp.code == SendLocationIntentResponseCode.failure ||
                resp.code == SendLocationIntentResponseCode.failureRequiringAppLaunch ||
                resp.code == SendLocationIntentResponseCode.failureClipboardNotParseable ||
                resp.code == SendLocationIntentResponseCode.failureConnectivity ||
                resp.code == SendLocationIntentResponseCode.failureGeocoding {

                print("Didn't receive success code", resp.code, resp)
                completion(resp)
                return
            }

            api.submitLocation(updateType: LocationUpdateTrigger.Siri, location: resp.location?.location,
                               visit: nil, zone: nil).done {
                                print("Successfully submitted location")

                                var respCode = SendLocationIntentResponseCode.success
                                if resp.source != .unknown && resp.source != .stored {
                                    respCode = SendLocationIntentResponseCode.successViaClipboard
                                }

                                completion(SendLocationIntentResponse(code: respCode, userActivity: resp.userActivity,
                                                                      place: resp.location, source: resp.source,
                                                                      pasteboardContents: resp.pasteboardContents))
                                return
                }.catch { error in
                    print("Error sending location during Siri Shortcut call: \(error)")
                    completion(SendLocationIntentResponse(code: .failure, userActivity: nil))
                    return
            }
        }

    }

    func parseForLocation(intent: SendLocationIntent, completion: @escaping (SendLocationIntentResponse) -> Void) {
        // If location is already set in the intent, use that. If not,
        // We attempt to grab pasteboard contents and split by comma.
        // The hope is the user has something like LAT,LONG on the pasteboard
        // and we can use that for a CLLocation to update location with.
        // If they don't have a string like that then we assume they have a address on pasteboard.

        if let place = intent.location {
            print("Location already set, returning")
            completion(SendLocationIntentResponse(code: .ready, userActivity: nil, place: place, source: .stored,
                                                  pasteboardContents: nil))
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
                        completion(SendLocationIntentResponse(code: .failureClipboardNotParseable, userActivity: nil,
                                                              pasteboardContents: pasteboardString))
                        return
                    }

                    print("Successfully parsed pasteboard contents to lat,long, returning")

                    // We use MKPlacemark so we can return a CLPlacemark without requiring use of the geocoder
                    completion(SendLocationIntentResponse(code: .ready, userActivity: nil,
                                                          place: MKPlacemark(coordinate: coord), source: .latlong,
                                                          pasteboardContents: pasteboardString))
                    return
                } else {
                    print("Thought we found a lat,long on clipboard, but it wasn't parseable as such, returning")
                    completion(SendLocationIntentResponse(code: .failureClipboardNotParseable, userActivity: nil,
                                                          pasteboardContents: pasteboardString))
                    return
                }
            } else { // Fallback to assuming that there's an address on there
                let geocoder = CLGeocoder()

                print("Not a lat,long, attempting geocode of string")
                geocoder.geocodeAddressString(pasteboardString) { (placemarks, error) in
                    if let error = error {
                        print("Error when geocoding string!", error)
                        completion(SendLocationIntentResponse(code: .failureGeocoding, userActivity: nil,
                                                              pasteboardContents: pasteboardString))
                        return
                    }
                    if let placemarks = placemarks {
                        print("Got a placemark!", placemarks[0])
                        completion(SendLocationIntentResponse(code: .ready, userActivity: nil,
                                                              place: placemarks[0], source: .address,
                                                              pasteboardContents: pasteboardString))
                        return
                    }
                }
            }
        } else {
            print("Nothing on Clipboard and a Placemark wasn't given, assuming user wants current location")
            completion(SendLocationIntentResponse(code: .ready, userActivity: nil,
                                                  place: nil, source: .unknown,
                                                  pasteboardContents: nil))
            return
        }
    }
}

extension SendLocationIntentResponse {
    convenience init(code: SendLocationIntentResponseCode, userActivity: NSUserActivity?, place: CLPlacemark?,
                     source: SendLocationClipboardLocationParsedAs, pasteboardContents: String?) {
        self.init(code: code, userActivity: userActivity, pasteboardContents: pasteboardContents)
        print("Confirming send location as place", place, "which was derived via", source)

        self.location = place
        self.source = source

        return
    }

    convenience init(code: SendLocationIntentResponseCode, userActivity: NSUserActivity?, pasteboardContents: String?) {
        self.init(code: code, userActivity: userActivity)
        self.pasteboardContents = pasteboardContents
    }
}
