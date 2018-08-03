//
//  DevicesMapViewController.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/8/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import UIKit
import MapKit

enum MapType: Int {
    case standard = 0
    case hybrid
    case satellite
}

class DeviceAnnotation: MKPointAnnotation {
    var device: DeviceTracker?
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

        let uploadIcon = getIconForIdentifier("mdi:upload",
                                              iconWidth: 30,
                                              iconHeight: 30,
                                              color: colorWithHexString("#44739E", alpha: 1))

        let leftBarItem = UIBarButtonItem(image: uploadIcon,
                                          style: .plain,
                                          target: self,
                                          action: #selector(DevicesMapViewController.sendCurrentLocation(_:)))

        self.navigationItem.leftBarButtonItem = leftBarItem

        let rightBarItem = UIBarButtonItem(barButtonSystemItem: .done,
                                           target: self,
                                           action: #selector(DevicesMapViewController.closeMapView(_:)))

        self.navigationItem.rightBarButtonItem = rightBarItem

        // Do any additional setup after loading the view.
        mapView = MKMapView()

        mapView.mapType = .standard
        mapView.frame = view.frame
        mapView.delegate = self
        mapView.showsUserLocation = false
        mapView.showsPointsOfInterest = false
        view.addSubview(mapView)

        let locateMeButton = MKUserTrackingBarButtonItem(mapView: mapView)
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: self, action: nil)
        let segmentedControlButtonItem = UIBarButtonItem(customView: typeController)
        //        let bookmarksButton = UIBarButtonItem(barButtonSystemItem: .Bookmarks, target: self, action: nil)

        self.setToolbarItems([locateMeButton, flexibleSpace, segmentedControlButtonItem, flexibleSpace], animated: true)

        if let cachedEntities = HomeAssistantAPI.sharedInstance.cachedEntities {
            if let zoneEntities: [Zone] = cachedEntities.filter({ (entity) -> Bool in
                return entity.Domain == "zone"
            }) as? [Zone] {
                for zone in zoneEntities {
                    // swiftlint:disable:next line_length
                    let circle = HACircle.init(center: zone.locationCoordinates(), radius: CLLocationDistance(zone.Radius))
                    circle.type = "zone"
                    mapView.addOverlay(circle)
                }
            }

            if let deviceEntities: [DeviceTracker] = cachedEntities.filter({ (entity) -> Bool in
                return entity.Domain == "device_tracker"
            }) as? [DeviceTracker] {
                for device in deviceEntities {
                    if device.Latitude == nil || device.Longitude == nil {
                        continue
                    }
                    let dropPin = DeviceAnnotation()
                    dropPin.coordinate = device.locationCoordinates()
                    dropPin.title = device.Name
                    var subtitlePieces: [String] = []
                    if let battery = device.Battery {
                        subtitlePieces.append(L10n.DevicesMap.batteryLabel+": "+String(battery)+"%")
                    }
                    dropPin.subtitle = subtitlePieces.joined(separator: " / ")
                    dropPin.device = device
                    mapView.addAnnotation(dropPin)

                    if let radius = device.GPSAccuracy {
                        let circle = HACircle.init(center: device.locationCoordinates(), radius: radius)
                        circle.type = "device"
                        mapView.addOverlay(circle)
                    }
                }
            }
        }

        var zoomRect: MKMapRect = MKMapRect.null
        for index in 0..<mapView.annotations.count {
            let annotation = mapView.annotations[index]
            let aPoint: MKMapPoint = MKMapPoint.init(annotation.coordinate)
            let rect: MKMapRect = MKMapRect.init(x: aPoint.x, y: aPoint.y, width: 0.1, height: 0.1)

            zoomRect = zoomRect.union(rect)
        }

        if let firstOverlay = mapView.overlays.first {
            let rect = mapView.overlays.reduce(firstOverlay.boundingMapRect, {$0.union($1.boundingMapRect)})

            mapView.setVisibleMapRect(zoomRect.union(rect),
                                      edgePadding: UIEdgeInsets(top: 10.0, left: 10.0, bottom: 10.0, right: 10.0),
                                      animated: true)
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
            let annotationView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: annotation.device?.ID)
            annotationView.animatesDrop = true
            annotationView.canShowCallout = true
            if let picture = annotation.device?.DownloadedPicture {
                annotationView.leftCalloutAccessoryView = UIImageView(image: picture)
            } else {
                annotationView.leftCalloutAccessoryView = UIImageView(image: annotation.device!.EntityIcon)
            }
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
        HomeAssistantAPI.sharedInstance.getAndSendLocation(trigger: .Manual).done { _ in
            let alert = UIAlertController(title: L10n.ManualLocationUpdateNotification.title,
                                          message: L10n.ManualLocationUpdateNotification.message,
                                          preferredStyle: UIAlertController.Style.alert)
            alert.addAction(UIAlertAction(title: L10n.okLabel, style: UIAlertAction.Style.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
            }.catch {error in
                let nserror = error as NSError
                let alert = UIAlertController(title: L10n.ManualLocationUpdateFailedNotification.title,
                    message: L10n.ManualLocationUpdateFailedNotification.message(nserror.localizedDescription),
                    preferredStyle: UIAlertController.Style.alert)
                alert.addAction(UIAlertAction(title: L10n.okLabel, style: UIAlertAction.Style.default, handler: nil))
                self.present(alert, animated: true, completion: nil)
        }
    }
}
