//
//  DevicesMapViewController.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/8/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import UIKit
import MapKit
import PromiseKit
import Shared

enum MapType: Int {
    case standard = 0
    case hybrid
    case satellite
}

class DeviceAnnotation: MKPointAnnotation {
    var device: RLMDeviceTracker?
}

// This is really just needed for UI Testing
class HAAnnotationView: MKPinAnnotationView {
    override func didMoveToSuperview() {
        super.didMoveToSuperview()

        self.accessibilityIdentifier = self.reuseIdentifier
    }
}

class HACircle: MKCircle {
    var type: String = "zone"
}

class DevicesMapViewController: UIViewController, MKMapViewDelegate {

    var mapView: MKMapView!

    // swiftlint:disable:next function_body_length
    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = L10n.DevicesMap.title

        self.navigationController?.isToolbarHidden = false

        let typeController = UISegmentedControl(items: [L10n.DevicesMap.MapTypes.standard,
                                                        L10n.DevicesMap.MapTypes.hybrid,
                                                        L10n.DevicesMap.MapTypes.satellite])
        typeController.selectedSegmentIndex = 0
        typeController.addTarget(self,
                                 action: #selector(DevicesMapViewController.switchMapType(_:)),
                                 for: .valueChanged)

        let uploadIcon = UIImage.iconForIdentifier("mdi:upload",
                                                   iconWidth: 30,
                                                   iconHeight: 30,
                                                   color: UIColor.defaultEntityColor)

        let leftBarItem = UIBarButtonItem(image: uploadIcon,
                                          style: .plain,
                                          target: self,
                                          action: #selector(DevicesMapViewController.sendCurrentLocation(_:)))

        self.navigationItem.leftBarButtonItem = leftBarItem

        let rightBarItem = UIBarButtonItem(barButtonSystemItem: .done,
                                           target: self,
                                           action: #selector(DevicesMapViewController.closeMapView(_:)))

        self.navigationItem.rightBarButtonItem = rightBarItem

        self.configureMapView()

        let locateMeButton = MKUserTrackingBarButtonItem(mapView: self.mapView)
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: self, action: nil)
        let segmentedControlButtonItem = UIBarButtonItem(customView: typeController)

        self.setToolbarItems([locateMeButton, flexibleSpace, segmentedControlButtonItem, flexibleSpace], animated: true)

        let zonesP = getZoneAnnotations()
        let devicesAP = getDeviceAnnotations()
        let devicesCP = getDeviceCircles()

        _ = when(fulfilled: zonesP, devicesAP, devicesCP).done { (zones, devices, deviceCircles) in
            self.mapView.addOverlays(zones)
            self.mapView.addAnnotations(devices)
            self.mapView.addOverlays(deviceCircles)

            var zoomRect: MKMapRect = MKMapRect.null
            for index in 0..<self.mapView.annotations.count {
                let annotation = self.mapView.annotations[index]
                let aPoint: MKMapPoint = MKMapPoint.init(annotation.coordinate)
                let rect: MKMapRect = MKMapRect.init(x: aPoint.x, y: aPoint.y, width: 0.1, height: 0.1)

                zoomRect = zoomRect.union(rect)
            }

            if let firstOverlay = self.mapView.overlays.first {
                let rect = self.mapView.overlays.reduce(firstOverlay.boundingMapRect, {$0.union($1.boundingMapRect)})

                self.mapView.setVisibleMapRect(zoomRect.union(rect),
                                          edgePadding: UIEdgeInsets(top: 10.0, left: 10.0, bottom: 10.0, right: 10.0),
                                          animated: true)
            }

        }

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @objc func switchMapType(_ sender: UISegmentedControl) {
        let mapType = MapType(rawValue: sender.selectedSegmentIndex)
        switch mapType! {
        case .standard:
            mapView.mapType = MKMapType.standard
        case .hybrid:
            mapView.mapType = MKMapType.hybrid
        case .satellite:
            mapView.mapType = MKMapType.satellite
        }
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if let annotation = annotation as? DeviceAnnotation {
            let annotationView = HAAnnotationView(annotation: annotation, reuseIdentifier: annotation.device?.ID)
            annotationView.animatesDrop = true
            annotationView.canShowCallout = true
            annotationView.leftCalloutAccessoryView = UIImageView(image: annotation.device!.EntityIcon)
            //            annotationView.rightCalloutAccessoryView = UIButton(type: .DetailDisclosure)
            return annotationView
        } else {
            return nil
        }
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let overlay = overlay as? HACircle {
            let circle = MKCircleRenderer(overlay: overlay)
            if overlay.type == "zone" {
                circle.strokeColor = UIColor.red
                circle.fillColor = UIColor.red.withAlphaComponent(0.1)
                circle.lineWidth = 1
                circle.lineDashPattern = [2, 5]
            } else if overlay.type == "device" {
                circle.strokeColor = UIColor.blue
                circle.fillColor = UIColor.blue.withAlphaComponent(0.1)
                circle.lineWidth = 1
            }
            return circle
        } else {
            return MKOverlayRenderer(overlay: overlay)
        }
    }

    @objc func closeMapView(_ sender: UIBarButtonItem) {
        self.navigationController?.dismiss(animated: true, completion: nil)
    }

    @objc func sendCurrentLocation(_ sender: UIBarButtonItem) {
        HomeAssistantAPI.authenticatedAPIPromise.then { api in
            api.GetAndSendLocation(trigger: .Manual)
            }.done { _ in
                let alert = UIAlertController(title: L10n.ManualLocationUpdateNotification.title,
                                              message: L10n.ManualLocationUpdateNotification.message,
                                              preferredStyle: UIAlertController.Style.alert)
                alert.addAction(UIAlertAction(title: L10n.okLabel, style: UIAlertAction.Style.default,
                                              handler: nil))
                self.present(alert, animated: true, completion: nil)
            }.catch {error in
                let nserror = error as NSError
                let errorDescription = nserror.localizedDescription
                let message = L10n.ManualLocationUpdateFailedNotification.message(errorDescription)
                let alert = UIAlertController(title: L10n.ManualLocationUpdateFailedNotification.title,
                                              message: message, preferredStyle: UIAlertController.Style.alert)
                alert.addAction(UIAlertAction(title: L10n.okLabel, style: UIAlertAction.Style.default,
                                              handler: nil))
                self.present(alert, animated: true, completion: nil)
        }
    }

    func getDeviceAnnotations() -> Promise<[DeviceAnnotation]> {
        return Promise { seal in
            let realm = Current.realm()
            let devices = Array(realm.objects(RLMDeviceTracker.self).map { $0 }).map({ device -> DeviceAnnotation in
                let dropPin = DeviceAnnotation()
                dropPin.coordinate = device.locationCoordinates()
                dropPin.title = device.Name
                var subtitlePieces: [String] = []
                if device.Battery > -1 {
                    subtitlePieces.append(L10n.DevicesMap.batteryLabel+": "+String(device.Battery)+"%")
                }
                dropPin.subtitle = subtitlePieces.joined(separator: " / ")
                dropPin.device = device
                return dropPin
            })
            seal.fulfill(devices)
        }
    }

    func getDeviceCircles() -> Promise<[HACircle]> {
        return Promise { seal in
            let realm = Current.realm()
            let devices = Array(realm.objects(RLMDeviceTracker.self).map { $0 }).compactMap({ device -> HACircle? in
                if device.GPSAccuracy > -1 {
                    let circle = HACircle.init(center: device.locationCoordinates(), radius: device.GPSAccuracy)
                    circle.type = "device"
                    return circle
                }
                return nil
            })
            seal.fulfill(devices)
        }
    }

    func getZoneAnnotations() -> Promise<[HACircle]> {
        return Promise { seal in
            let realm = Current.realm()
            let zones = Array(realm.objects(RLMZone.self).map { $0 })

            let zoneOverlays = zones.map({ zone -> HACircle in
                let circle = HACircle.init(center: zone.locationCoordinates(),
                                           radius: CLLocationDistance(zone.Radius))
                circle.type = "zone"
                return circle
            })

            seal.fulfill(zoneOverlays)
        }
    }

    // MARK: - Private helpers

    private func configureMapView() {
        self.mapView = MKMapView()

        self.mapView.mapType = .standard
        self.mapView.frame = view.frame
        self.mapView.delegate = self
        self.mapView.showsUserLocation = false
        self.mapView.showsPointsOfInterest = false
        view.addSubview(self.mapView)
    }
}
