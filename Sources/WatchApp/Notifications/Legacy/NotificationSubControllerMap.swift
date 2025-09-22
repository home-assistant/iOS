import Foundation
import PromiseKit
import Shared
import UserNotifications
import WatchKit
import MapKit

class NotificationSubControllerMap: NotificationSubController {
    let api: HomeAssistantAPI
    let location: CLLocationCoordinate2D
    let secondLocation: CLLocationCoordinate2D?

    required init?(api: HomeAssistantAPI, notification: UNNotification) {
        let userInfo = notification.request.content.userInfo

        guard let haDict = userInfo["homeassistant"] as? [String: Any],
              let latitude = CLLocationDegrees(templateValue: haDict["latitude"]),
              let longitude = CLLocationDegrees(templateValue: haDict["longitude"]) else {
            return nil
        }

        self.api = api
        self.location = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

        if let secondLatitude = CLLocationDegrees(templateValue: haDict["second_latitude"]),
           let secondLongitude = CLLocationDegrees(templateValue: haDict["second_longitude"]) {
            self.secondLocation = CLLocationCoordinate2D(latitude: secondLatitude, longitude: secondLongitude)
        } else {
            self.secondLocation = nil
        }
    }

    required init?(api: HomeAssistantAPI, url: URL) {
        nil
    }

    func start() -> DynamicContent {
        // Build pins
        var pinLocations: [CLLocationCoordinate2D] = [location]
        var pins: [MKPointAnnotation] = []

        let firstPin = MKPointAnnotation()
        firstPin.coordinate = location
        pins.append(firstPin)

        if let secondLocation {
            pinLocations.append(secondLocation)
            let secondPin = MKPointAnnotation()
            secondPin.coordinate = secondLocation
            pins.append(secondPin)
        }

        // Compute region: single pin = default span; two pins = fit both
        var region = MKCoordinateRegion(
            center: pinLocations[0],
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )

        if pinLocations.count > 1 {
            region = MKCoordinateRegion(coordinates: pinLocations)
        }

        return .map(region: region, pins: pins)
    }

    func stop() {
        // nothing to stop
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

        let span = MKCoordinateSpan(latitudeDelta: (maxLat - minLat) * 2.0, longitudeDelta: (maxLon - minLon) * 2.0)
        let center = CLLocationCoordinate2DMake(maxLat - span.latitudeDelta / 4, maxLon - span.longitudeDelta / 4)
        self.init(center: center, span: span)
    }
}

