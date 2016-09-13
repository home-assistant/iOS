//
//  DevicesMapViewController.swift
//  HomeAssistant
//
//  Created by Robbie Trencheny on 4/8/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import UIKit
import MapKit
import RealmSwift

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
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = "Devices & Zones"
        
        self.navigationController?.isToolbarHidden = false
        
        let items = ["Standard", "Hybrid", "Satellite"]
        let typeController = UISegmentedControl(items: items)
        typeController.selectedSegmentIndex = 0
        typeController.addTarget(self, action: #selector(DevicesMapViewController.switchMapType(_:)), for: .valueChanged)
        
        let uploadIcon = getIconForIdentifier("mdi:upload", iconWidth: 30, iconHeight: 30, color: colorWithHexString("#44739E", alpha: 1))
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(image: uploadIcon, style: .plain, target: self, action: #selector(DevicesMapViewController.sendCurrentLocation(_:)))
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(DevicesMapViewController.closeMapView(_:)))
        
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
        
        for zone in realm.allObjects(ofType: Zone.self) {
            let circle = HACircle.init(center: zone.locationCoordinates(), radius: CLLocationDistance(zone.Radius))
            circle.type = "zone"
            mapView.add(circle)
        }
        
        for device in realm.allObjects(ofType: DeviceTracker.self) {
            if device.Latitude.value == nil || device.Longitude.value == nil {
                continue
            }
            let dropPin = DeviceAnnotation()
            dropPin.coordinate = device.locationCoordinates()
            dropPin.title = device.Name
            var subtitlePieces : [String] = []
//            if let changedTime = device.LastChanged {
//                subtitlePieces.append("Last seen: "+changedTime.toRelativeString(abbreviated: true, maxUnits: 1)!+" ago")
//            }
            if let battery = device.Battery.value {
                subtitlePieces.append("Battery: "+String(battery)+"%")
            }
            dropPin.subtitle = subtitlePieces.joined(separator: " / ")
            dropPin.device = device
            mapView.addAnnotation(dropPin)
            
            if let radius = device.GPSAccuracy.value {
                let circle = HACircle.init(center: device.locationCoordinates(), radius: radius)
                circle.type = "device"
                mapView.add(circle)
            }
            
        }
        
        var zoomRect:MKMapRect = MKMapRectNull
        for index in 0..<mapView.annotations.count {
            let annotation = mapView.annotations[index]
            let aPoint:MKMapPoint = MKMapPointForCoordinate(annotation.coordinate)
            let rect:MKMapRect = MKMapRectMake(aPoint.x, aPoint.y, 0.1, 0.1)
            
            zoomRect = MKMapRectUnion(zoomRect, rect)
        }

        let rect = mapView.overlays.reduce(mapView.overlays.first!.boundingMapRect, {MKMapRectUnion($0, $1.boundingMapRect)})
        
        mapView.setVisibleMapRect(MKMapRectUnion(zoomRect, rect), edgePadding: UIEdgeInsets(top: 10.0, left: 10.0, bottom: 10.0, right: 10.0), animated: true)
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func switchMapType(_ sender: UISegmentedControl) {
        let mapType = MapType(rawValue: sender.selectedSegmentIndex)
        switch (mapType!) {
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
    
    func closeMapView(_ sender: UIBarButtonItem) {
        self.navigationController?.dismiss(animated: true, completion: nil)
    }
    
    func sendCurrentLocation(_ sender: UIBarButtonItem) {
        HomeAssistantAPI.sharedInstance.sendOneshotLocation(notifyString: "One off location update requested").then { success -> Void in
            let alert = UIAlertController(title: "Location updated", message: "Successfully sent a one shot location to the server", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }.catch {error in
            let nserror = error as NSError
            let alert = UIAlertController(title: "Location failed to update", message: "Failed to send current location to server. The error was \(nserror.localizedDescription)", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }
}
