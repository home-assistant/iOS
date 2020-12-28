//
//  MapNotificationController.swift
//  WatchAppExtension
//
//  Created by Robert Trencheny on 2/27/19.
//  Copyright © 2019 Robbie Trencheny. All rights reserved.
//

import WatchKit
import Foundation
import UserNotifications
import MapKit
import Shared

class MapNotificationController: WKUserNotificationInterfaceController {

    @IBOutlet weak var mapView: WKInterfaceMap!

    @IBOutlet weak var notificationTitleLabel: WKInterfaceLabel!
    @IBOutlet weak var notificationSubtitleLabel: WKInterfaceLabel!
    @IBOutlet weak var notificationAlertLabel: WKInterfaceLabel!

    // MARK: - WKUserNotificationInterfaceController

    override func didReceive(_ notification: UNNotification) {
        self.notificationTitleLabel.setText(notification.request.content.title)
        self.notificationSubtitleLabel.setText(notification.request.content.subtitle)
        self.notificationAlertLabel!.setText(notification.request.content.body)

        let userInfo = notification.request.content.userInfo

        guard let haDict = userInfo["homeassistant"] as? [String: Any] else {
            Current.Log.error(L10n.Extensions.Map.PayloadMissingHomeassistant.message)
            return
        }
        guard let latitude = CLLocationDegrees(templateValue: haDict["latitude"]) else {
            Current.Log.error(L10n.Extensions.Map.ValueMissingOrUncastable.Latitude.message)
            return
        }
        guard let longitude = CLLocationDegrees(templateValue: haDict["longitude"]) else {
            Current.Log.error(L10n.Extensions.Map.ValueMissingOrUncastable.Longitude.message)
            return
        }
        let location = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

        var pinLocations: [CLLocationCoordinate2D] = [location]

        self.mapView.addAnnotation(location, with: .red)

        if let secondLatitude = CLLocationDegrees(templateValue: haDict["second_latitude"]),
           let secondLongitude = CLLocationDegrees(templateValue: haDict["second_longitude"]) {
            let secondCoords = CLLocationCoordinate2D(latitude: secondLatitude, longitude: secondLongitude)

            pinLocations.append(secondCoords)

            self.mapView.addAnnotation(secondCoords, with: .green)
        }

        var region = MKCoordinateRegion(center: pinLocations[0],
                                        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1))

        if pinLocations.count > 1 {
            region = MKCoordinateRegion(coordinates: pinLocations)
        }

        self.mapView.setRegion(region)
    }

}

extension MKCoordinateRegion {
    init(coordinates: [CLLocationCoordinate2D]) {
        var minLat: CLLocationDegrees = 90.0
        var maxLat: CLLocationDegrees = -90.0
        var minLon: CLLocationDegrees = 180.0
        var maxLon: CLLocationDegrees = -180.0

        for coordinate in coordinates {
            let lat = Double(coordinate.latitude)
            let long = Double(coordinate.longitude)
            if lat < minLat {
                minLat = lat
            }
            if long < minLon {
                minLon = long
            }
            if lat > maxLat {
                maxLat = lat
            }
            if long > maxLon {
                maxLon = long
            }
        }

        let span = MKCoordinateSpan(latitudeDelta: (maxLat - minLat)*2.0, longitudeDelta: (maxLon - minLon)*2.0)
        let center = CLLocationCoordinate2DMake(maxLat - span.latitudeDelta / 4, maxLon - span.longitudeDelta / 4)
        self.init(center: center, span: span)
    }
}
