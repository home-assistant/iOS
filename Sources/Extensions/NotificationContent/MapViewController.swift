//
//  Map.swift
//  NotificationContentExtension
//
//  Created by Robert Trencheny on 10/2/18.
//  Copyright © 2018 Robbie Trencheny. All rights reserved.
//

import UIKit
import UserNotifications
import UserNotificationsUI
import MapKit
import PromiseKit
import Shared

class MapViewController: UIViewController, NotificationCategory, MKMapViewDelegate {
    private var mapView: MKMapView!

    enum MapError: LocalizedError {
        case missingPayload
        case missingLatitude
        case missingLongitude

        var errorDescription: String? {
            switch self {
            case .missingPayload:
                return L10n.Extensions.Map.PayloadMissingHomeassistant.message
            case .missingLatitude:
                return L10n.Extensions.Map.ValueMissingOrUncastable.Latitude.message
            case .missingLongitude:
                return L10n.Extensions.Map.ValueMissingOrUncastable.Longitude.message
            }
        }
    }

    // swiftlint:disable:next function_body_length
    func didReceive(notification: UNNotification, extensionContext: NSExtensionContext?) -> Promise<Void> {
        let userInfo = notification.request.content.userInfo

        guard let haDict = userInfo["homeassistant"] as? [String: Any] else {
            return .init(error: MapError.missingPayload)
        }
        guard let latitude = CLLocationDegrees(templateValue: haDict["latitude"]) else {
            return .init(error: MapError.missingLatitude)
        }
        guard let longitude = CLLocationDegrees(templateValue: haDict["longitude"]) else {
            return .init(error: MapError.missingLongitude)
        }
        let location = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        self.mapView = MKMapView()

        self.mapView.delegate = self
        self.mapView.mapType = .standard
        self.mapView.frame = view.frame

        self.mapView.showsUserLocation = (haDict["shows_user_location"] != nil)
        self.mapView.showsPointsOfInterest = (haDict["shows_points_of_interest"] != nil)
        self.mapView.showsCompass = (haDict["shows_compass"] != nil)
        self.mapView.showsScale = (haDict["shows_scale"] != nil)
        self.mapView.showsTraffic = (haDict["shows_traffic"] != nil)

        self.mapView.accessibilityIdentifier = "notification_map"

        let span = MKCoordinateSpan.init(latitudeDelta: 0.1, longitudeDelta: 0.1)
        let region = MKCoordinateRegion(center: location, span: span)
        self.mapView.setRegion(region, animated: true)
        view.addSubview(self.mapView)

        let dropPin = MKPointAnnotation()
        dropPin.coordinate = location

        if let secondLatitude = CLLocationDegrees(templateValue: haDict["second_latitude"]),
           let secondLongitude = CLLocationDegrees(templateValue: haDict["second_longitude"]) {
            let secondDropPin = MKPointAnnotation()
            secondDropPin.coordinate = CLLocationCoordinate2D(latitude: secondLatitude, longitude: secondLongitude)
            secondDropPin.title = L10n.Extensions.Map.Location.new
            self.mapView.addAnnotation(secondDropPin)

            self.mapView.selectAnnotation(secondDropPin, animated: true)

            dropPin.title = L10n.Extensions.Map.Location.original
        }

        self.mapView.addAnnotation(dropPin)

        if mapView.annotations.count > 1 {
            if haDict["shows_line_between_points"] != nil {
                var polylinePoints: [CLLocationCoordinate2D] = [CLLocationCoordinate2D]()

                for annotation in self.mapView.annotations {
                    polylinePoints.append(annotation.coordinate)
                }
                self.mapView.addOverlay(MKPolyline(coordinates: &polylinePoints, count: polylinePoints.count))
            }

            mapView.showAnnotations(mapView.annotations, animated: true)
            mapView.camera.altitude *= 1.4
        }

        return .value(())
    }

    var mediaPlayPauseButtonType: UNNotificationContentExtensionMediaPlayPauseButtonType { .none }
    var mediaPlayPauseButtonFrame: CGRect?
    var mediaPlayPauseButtonTintColor: UIColor?
    func mediaPlay() {}
    func mediaPause() {}

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation {
            // if annotation is not an MKPointAnnotation (eg. MKUserLocation),
            // return nil so map draws default view for it (eg. blue dot)...
            return nil
        }

        let pinView: MKPinAnnotationView = MKPinAnnotationView()
        pinView.annotation = annotation
        if let title = annotation.title {
            if title == L10n.Extensions.Map.Location.original {
                pinView.pinTintColor = .red
            } else if title == L10n.Extensions.Map.Location.new {
                pinView.pinTintColor = .green
            }
        } else {
            pinView.pinTintColor = .red
        }
        pinView.animatesDrop = true
        pinView.canShowCallout = true

        return pinView
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let polylineRenderer = MKPolylineRenderer(overlay: overlay)
        polylineRenderer.strokeColor = UIColor.red
        polylineRenderer.fillColor = UIColor.red.withAlphaComponent(0.1)
        polylineRenderer.lineWidth = 1
        polylineRenderer.lineDashPattern = [2, 5]
        return polylineRenderer
    }
}
