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
import MBProgressHUD
import KeychainAccess

class NotificationViewController: UIViewController, UNNotificationContentExtension {

    var hud: MBProgressHUD?

    private var baseURL: String = ""

    let urlConfiguration: URLSessionConfiguration = URLSessionConfiguration.default

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any required interface initialization here.

        let keychain = Keychain(service: "io.robbie.homeassistant", accessGroup: "UTQFCBPQRF.io.robbie.HomeAssistant")
        print("\(keychain)")
        if let url = keychain["baseURL"] {
            baseURL = url
        }
        if let pass = keychain["apiPassword"] {
            urlConfiguration.httpAdditionalHeaders = ["X-HA-Access": pass]
        }
    }

    func didReceive(_ notification: UNNotification) {
        print("Received a \(notification.request.content.categoryIdentifier) notification type")
        let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
        hud.detailsLabel.text = "Loading \(notification.request.content.categoryIdentifier)..."
        hud.offset = CGPoint(x: 0, y: -MBProgressMaxOffset+50)
        self.hud = hud
        switch notification.request.content.categoryIdentifier {
        case "map":
            mapHandler(notification)
        case "camera":
            cameraHandler(notification)
        default:
            return
        }
    }

    func mapHandler(_ notification: UNNotification) {
        if let haDict = notification.request.content.userInfo["homeassistant"] as? [String:Any] {
            guard let latitudeString = haDict["latitude"] as? String else { return }
            guard let longitudeString = haDict["longitude"] as? String else { return }
            let latitude = Double.init(latitudeString)! as CLLocationDegrees
            let longitude = Double.init(longitudeString)! as CLLocationDegrees

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
            snapshotter.start { snapshot, _ in

                let image = snapshot!.image

                let pin = MKPinAnnotationView(annotation: nil, reuseIdentifier: "")
                let pinImage = pin.image

                UIGraphicsBeginImageContextWithOptions(image.size, true, image.scale)

                image.draw(at: CGPoint(x: 0, y: 0))

                let homePoint = snapshot?.point(for: mapCoordinate)
                pinImage?.draw(at: homePoint!)

                let finalImage = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()

                let imageView = UIImageView(image: finalImage)
                imageView.frame = self.view.frame
                imageView.contentMode = .scaleAspectFit
                self.view.addSubview(imageView)
                self.hud!.hide(animated: true)
                self.preferredContentSize = CGSize(width: 0, height: imageView.frame.maxY)
            }
        }
    }

    func cameraHandler(_ notification: UNNotification) {
        guard let entityId = notification.request.content.userInfo["entity_id"] as? String else { return }
        guard let cameraProxyURL = URL(string: "\(baseURL)/api/camera_proxy_stream/\(entityId)") else { return }

        let imageView = UIImageView()
        imageView.frame = self.view.frame
        imageView.contentMode = .scaleAspectFit

        let streamingController = MjpegStreamingController(imageView: imageView,
                                                           contentURL: cameraProxyURL,
                                                           sessionConfiguration: urlConfiguration)
        streamingController.didFinishLoading = { _ in
            print("Finished loading")
            self.hud!.hide(animated: true)

            self.view.addSubview(imageView)
        }
        streamingController.play()
    }

}
