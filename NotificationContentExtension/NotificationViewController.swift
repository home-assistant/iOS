//
//  NotificationViewController.swift
//  NotificationContentExtension
//
//  Created by Robbie Trencheny on 9/9/16.
//  Copyright © 2016 Robbie Trencheny. All rights reserved.
//

import UIKit
import UserNotifications
import UserNotificationsUI
import MapKit

class NotificationViewController: UIViewController, UNNotificationContentExtension {

    @IBOutlet var label: UILabel?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any required interface initialization here.
    }
    
    func didReceive(_ notification: UNNotification) {
        switch (notification.request.content.categoryIdentifier) {
            case "mapNotification":
                buildMapView(notification)
            default:
                buildMapView(notification)
        }
    }
    
    func buildMapView(_ notification: UNNotification) {
        let haDict = notification.request.content.userInfo["homeassistant"] as! [String:Any]
        let latitude = haDict["latitude"] as! CLLocationDegrees
        let longitude = haDict["longitude"] as! CLLocationDegrees
        
        let mapCoordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let span = MKCoordinateSpanMake(0.1, 0.1)
        
        let options = MKMapSnapshotOptions()
        options.mapType = .standard
        options.showsPointsOfInterest = false
        options.showsBuildings = false
        options.region = MKCoordinateRegion(center: mapCoordinate, span: span)
        options.size = self.view.frame.size
        options.scale = self.view.contentScaleFactor
        
        let snapshotter = MKMapSnapshotter(options: options)
        snapshotter.start() { snapshot, error in
            
            let image = snapshot!.image
            
            let pin = MKPinAnnotationView(annotation: nil, reuseIdentifier: "")
            let pinImage = pin.image
            
            UIGraphicsBeginImageContextWithOptions(image.size, true, image.scale);
            
            image.draw(at: CGPoint(x: 0, y: 0))
            
            let homePoint = snapshot?.point(for: mapCoordinate)
            pinImage?.draw(at: homePoint!)
            
            let finalImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            let imageView = UIImageView(image: finalImage)
            imageView.frame = self.view.frame
            imageView.contentMode = .scaleAspectFit
            self.view.addSubview(imageView)
        }
    }

}
