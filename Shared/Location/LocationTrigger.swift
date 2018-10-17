//
//  LocationTrigger.swift
//  Shared
//
//  Created by Stephan Vanterpool on 9/15/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import CoreLocation
import Foundation
private let prefs = UserDefaults(suiteName: Constants.AppGroupID)!
public enum LocationUpdateTrigger: String {

    public struct NotificationOptions {
        public let shouldNotify: Bool
        public let identifier: String?
        public let title: String
        public let body: String
    }

    case RegionEnter = "Region Entered"
    case RegionExit = "Region Exited"
    case GPSRegionEnter = "Geographic Region Entered"
    case GPSRegionExit = "Geographic Region Exited"
    case BeaconRegionEnter = "iBeacon Region Entered"
    case BeaconRegionExit = "iBeacon Region Exited"
    case Manual = "Manual"
    case SignificantLocationUpdate = "Significant Location Update"
    case BackgroundFetch = "Background Fetch"
    case PushNotification = "Push Notification"
    case URLScheme = "URL Scheme"
    case Visit = "Visit"
    case Unknown = "Unknown"

    public func notificationOptionsFor(zoneName: String) -> NotificationOptions {
        let shouldNotify: Bool
        var identifier: String = ""
        let body: String
        let title = "Location change"

        switch self {
        case .BeaconRegionEnter:
            body = L10n.LocationChangeNotification.BeaconRegionEnter.body(zoneName)
            identifier = "\(zoneName)_beacon_entered"
            shouldNotify = prefs.bool(forKey: "beaconEnterNotifications")
        case .BeaconRegionExit:
            body = L10n.LocationChangeNotification.BeaconRegionExit.body(zoneName)
            identifier = "\(zoneName)_beacon_exited"
            shouldNotify = prefs.bool(forKey: "beaconExitNotifications")
        case .GPSRegionEnter:
            body = L10n.LocationChangeNotification.RegionEnter.body(zoneName)
            identifier = "\(zoneName)_entered"
            shouldNotify = prefs.bool(forKey: "enterNotifications")
        case .GPSRegionExit:
            body = L10n.LocationChangeNotification.RegionExit.body(zoneName)
            identifier = "\(zoneName)_exited"
            shouldNotify = prefs.bool(forKey: "exitNotifications")
        case .SignificantLocationUpdate:
            body = L10n.LocationChangeNotification.SignificantLocationUpdate.body
            identifier = "sig_change"
            shouldNotify = prefs.bool(forKey: "significantLocationChangeNotifications")
        case .BackgroundFetch:
            body = L10n.LocationChangeNotification.BackgroundFetch.body
            identifier = "background_fetch"
            shouldNotify = prefs.bool(forKey: "backgroundFetchLocationChangeNotifications")
        case .PushNotification:
            body = L10n.LocationChangeNotification.PushNotification.body
            identifier = "push_notification"
            shouldNotify = prefs.bool(forKey: "pushLocationRequestNotifications")
        case .URLScheme:
            body = L10n.LocationChangeNotification.UrlScheme.body
            identifier = "url_scheme"
            shouldNotify = prefs.bool(forKey: "urlSchemeLocationRequestNotifications")
        case .Visit:
            body = L10n.LocationChangeNotification.Visit.body
            shouldNotify = false
        case .Manual:
            body = L10n.LocationChangeNotification.Manual.body
            shouldNotify = false
        case .RegionExit, .RegionEnter, .Unknown:
            body = L10n.LocationChangeNotification.Unknown.body
            shouldNotify = false
        }

        return NotificationOptions(shouldNotify: shouldNotify, identifier: identifier, title: title, body: body)
    }
}
