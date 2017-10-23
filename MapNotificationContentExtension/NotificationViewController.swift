//
//  NotificationViewController.swift
//  MapNotificationContentExtension
//
//  Created by Robert Trencheny on 4/20/17.
//  Copyright © 2017 Robbie Trencheny. All rights reserved.
//

import UIKit
import UserNotifications
import UserNotificationsUI
import MBProgressHUD
import MapKit

class NotificationViewController: UIViewController, UNNotificationContentExtension, MKMapViewDelegate {

    var hud: MBProgressHUD?

    var mapView: MKMapView!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any required interface initialization here.
    }

    // swiftlint:disable:next function_body_length
    func didReceive(_ notification: UNNotification) {
        print("Received a map notification")
        let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
        hud.detailsLabel.text = "Loading \(notification.request.content.categoryIdentifier)..."
        hud.offset = CGPoint(x: 0, y: -MBProgressMaxOffset+50)
        self.hud = hud
        guard let haDict = notification.request.content.userInfo["homeassistant"] as? [String: Any] else {
            self.showErrorLabel(message: "Payload didn't contain a homeassistant dictionary!")
            return
        }
        guard let latitudeString = haDict["latitude"] as? String else {
            self.showErrorLabel(message: "Latitude wasn't found or couldn't be casted to string!")
            return
        }
        guard let longitudeString = haDict["longitude"] as? String else {
            self.showErrorLabel(message: "Longitude wasn't found or couldn't be casted to string!")
            return
        }
        let latitude = Double.init(latitudeString)! as CLLocationDegrees
        let longitude = Double.init(longitudeString)! as CLLocationDegrees
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

        let span = MKCoordinateSpanMake(0.1, 0.1)
        let region = MKCoordinateRegion(center: location, span: span)
        self.mapView.setRegion(region, animated: true)
        view.addSubview(self.mapView)

        let dropPin = MKPointAnnotation()
        dropPin.coordinate = location

        if let secondLatitudeString = haDict["second_latitude"] as? String,
            let secondLongitudeString = haDict["second_longitude"] as? String {
            let secondLatitude = Double.init(secondLatitudeString)! as CLLocationDegrees
            let secondLongitude = Double.init(secondLongitudeString)! as CLLocationDegrees
            let secondDropPin = MKPointAnnotation()
            secondDropPin.coordinate = CLLocationCoordinate2D(latitude: secondLatitude, longitude: secondLongitude)
            secondDropPin.title = "New Location"
            self.mapView.addAnnotation(secondDropPin)

            self.mapView.selectAnnotation(secondDropPin, animated: true)

            dropPin.title = "Original Location"
        }

        self.mapView.addAnnotation(dropPin)

        if mapView.annotations.count > 1 {
            if haDict["shows_line_between_points"] != nil {
                var polylinePoints: [CLLocationCoordinate2D] = [CLLocationCoordinate2D]()

                for annotation in self.mapView.annotations {
                    polylinePoints.append(annotation.coordinate)
                }
                self.mapView.add(MKPolyline(coordinates: &polylinePoints, count: polylinePoints.count))
            }

            mapView.showAnnotations(mapView.annotations, animated: true)
            mapView.camera.altitude *= 1.4
        }

    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation {
            //if annotation is not an MKPointAnnotation (eg. MKUserLocation),
            //return nil so map draws default view for it (eg. blue dot)...
            return nil
        }

        let pinView: MKPinAnnotationView = MKPinAnnotationView()
        pinView.annotation = annotation
        if let title = annotation.title {
            if title == "Original Location" {
                pinView.pinTintColor = .red
            } else if title == "New Location" {
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

    func showErrorLabel(message: String) {
        self.hud?.hide(animated: true)
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: self.view.frame.width, height: 60))
        label.center.y = self.view.center.y
        label.textAlignment = .center
        label.textColor = .red
        label.text = message
        label.lineBreakMode = .byWordWrapping
        label.numberOfLines = 0
        self.view.addSubview(label)
    }

}
