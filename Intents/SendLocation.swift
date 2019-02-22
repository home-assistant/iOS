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
            Current.Log.error("Can't get a authenticated API \(error)")
            completion(SendLocationIntentResponse(code: .failureConnectivity, userActivity: nil))
            return
        }

        parseForLocation(intent: intent, completion: completion)
    }

    func handle(intent: SendLocationIntent, completion: @escaping (SendLocationIntentResponse) -> Void) {
        Current.Log.verbose("Handling send location")

        guard let api = HomeAssistantAPI.authenticatedAPI() else {
            Current.Log.error("Failed to get Home Assistant API during handle of sendLocation")
            completion(SendLocationIntentResponse(code: .failureConnectivity, userActivity: nil))
            return
        }

        parseForLocation(intent: intent) { (resp) in
            if resp.code == SendLocationIntentResponseCode.failure ||
                resp.code == SendLocationIntentResponseCode.failureRequiringAppLaunch ||
                resp.code == SendLocationIntentResponseCode.failureClipboardNotParseable ||
                resp.code == SendLocationIntentResponseCode.failureConnectivity ||
                resp.code == SendLocationIntentResponseCode.failureGeocoding {

                Current.Log.error("Didn't receive success code \(resp.code), \(resp)")
                completion(resp)
                return
            }

            api.submitLocation(updateType: .Siri, location: resp.location?.location, zone: nil).done {
                Current.Log.verbose("Successfully submitted location")

                var respCode = SendLocationIntentResponseCode.success
                if resp.source != .unknown && resp.source != .stored {
                    respCode = SendLocationIntentResponseCode.successViaClipboard
                }

                completion(SendLocationIntentResponse(code: respCode, userActivity: resp.userActivity,
                                                      place: resp.location, source: resp.source,
                                                      clipboardContents: resp.clipboardContents))
                return
            }.catch { error in
                Current.Log.error("Error sending location during Siri Shortcut call: \(error)")
                let resp = SendLocationIntentResponse(code: .failure, userActivity: nil)
                resp.error = "Error sending location during Siri Shortcut call: \(error.localizedDescription)"
                completion(resp)
                return
            }
        }

    }

    // swiftlint:disable:next function_body_length
    func parseForLocation(intent: SendLocationIntent, completion: @escaping (SendLocationIntentResponse) -> Void) {
        // If location is already set in the intent, use that. If not,
        // We attempt to grab pasteboard contents and split by comma.
        // The hope is the user has something like LAT,LONG on the pasteboard
        // and we can use that for a CLLocation to update location with.
        // If they don't have a string like that then we assume they have a address on pasteboard.

        if let place = intent.location {
            Current.Log.verbose("Location already set, returning")
            completion(SendLocationIntentResponse(code: .ready, userActivity: nil, place: place, source: .stored,
                                                  clipboardContents: nil))
            return
        } else if let pasteboardString = UIPasteboard.general.string {
            Current.Log.verbose("Pasteboard contains... \(pasteboardString)")
            let allowedLatLongChars = CharacterSet(charactersIn: "0123456789,-.")
            if pasteboardString.rangeOfCharacter(from: allowedLatLongChars.inverted) == nil {
                Current.Log.verbose("Appears we have a lat,long formatted string")
                let splitString = pasteboardString.components(separatedBy: ",")
                if let latitude = CLLocationDegrees(splitString[0]), let longitude = CLLocationDegrees(splitString[1]) {
                    let coord = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

                    if !CLLocationCoordinate2DIsValid(coord) {
                        Current.Log.warning("Invalid coords!! \(coord)")
                        completion(SendLocationIntentResponse(code: .failureClipboardNotParseable, userActivity: nil,
                                                              clipboardContents: pasteboardString))
                        return
                    }

                    Current.Log.verbose("Successfully parsed pasteboard contents to lat,long, returning")

                    // We use MKPlacemark so we can return a CLPlacemark without requiring use of the geocoder
                    completion(SendLocationIntentResponse(code: .ready, userActivity: nil,
                                                          place: MKPlacemark(coordinate: coord), source: .latlong,
                                                          clipboardContents: pasteboardString))
                    return
                } else {
                    Current.Log.warning("Thought we found a lat,long on clipboard, but it wasn't parseable, returning")
                    completion(SendLocationIntentResponse(code: .failureClipboardNotParseable, userActivity: nil,
                                                          clipboardContents: pasteboardString))
                    return
                }
            } else { // Fallback to assuming that there's an address on there
                let geocoder = CLGeocoder()

                Current.Log.warning("Not a lat,long, attempting geocode of string")
                geocoder.geocodeAddressString(pasteboardString) { (placemarks, error) in
                    if let error = error {
                        Current.Log.error("Error when geocoding string, sending current location instead! \(error)")
                        completion(SendLocationIntentResponse(code: .ready, userActivity: nil,
                                                              place: nil, source: .unknown,
                                                              clipboardContents: nil))
//                        completion(SendLocationIntentResponse(code: .failureGeocoding, userActivity: nil,
//                                                              clipboardContents: pasteboardString))
                        return
                    }
                    if let placemarks = placemarks {
                        Current.Log.verbose("Got a placemark! \(placemarks[0])")
                        completion(SendLocationIntentResponse(code: .ready, userActivity: nil,
                                                              place: placemarks[0], source: .address,
                                                              clipboardContents: pasteboardString))
                        return
                    }
                }
            }
        } else {
            Current.Log.verbose("Nothing on Clipboard and Placemark wasn't set, assuming user wants current location")
            completion(SendLocationIntentResponse(code: .ready, userActivity: nil,
                                                  place: nil, source: .unknown,
                                                  clipboardContents: nil))
            return
        }
    }
}

extension SendLocationIntentResponse {
    convenience init(code: SendLocationIntentResponseCode, userActivity: NSUserActivity?, place: CLPlacemark?,
                     source: SendLocationClipboardLocationParsedAs, clipboardContents: String?) {
        self.init(code: code, userActivity: userActivity, clipboardContents: clipboardContents)
        Current.Log.verbose("Confirming send location as place \(place.debugDescription) derived via \(source)")

        self.location = place
        self.source = source

        return
    }

    convenience init(code: SendLocationIntentResponseCode, userActivity: NSUserActivity?, clipboardContents: String?) {
        self.init(code: code, userActivity: userActivity)
        self.clipboardContents = clipboardContents
    }
}
