import MapKit
import PromiseKit
import Shared
import UIKit
import UserNotifications
import UserNotificationsUI

class MapViewController: UIViewController, NotificationCategory, MKMapViewDelegate {
    let api: HomeAssistantAPI
    let location: CLLocationCoordinate2D
    let haDict: [String: Any]

    required init(api: HomeAssistantAPI, notification: UNNotification, attachmentURL: URL?) throws {
        guard let haDict = notification.request.content.userInfo["homeassistant"] as? [String: Any] else {
            throw MapError.missingPayload
        }
        guard let latitude = CLLocationDegrees(templateValue: haDict["latitude"]) else {
            throw MapError.missingLatitude
        }
        guard let longitude = CLLocationDegrees(templateValue: haDict["longitude"]) else {
            throw MapError.missingLongitude
        }

        self.api = api
        self.haDict = haDict
        self.location = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

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

    override func viewDidLoad() {
        super.viewDidLoad()

        NSLayoutConstraint.activate([
            view.heightAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.5625),
        ])
    }

    func start() -> Promise<Void> {
        let mapView = MKMapView()
        view.addSubview(mapView)

        mapView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        mapView.delegate = self
        mapView.mapType = .standard
        mapView.showsUserLocation = (haDict["shows_user_location"] != nil)

        if #available(iOS 13, *) {
            if haDict["shows_points_of_interest"] != nil {
                mapView.pointOfInterestFilter = .includingAll
            } else {
                mapView.pointOfInterestFilter = .excludingAll
            }
        } else {
            mapView.showsPointsOfInterest = (haDict["shows_points_of_interest"] != nil)
        }

        mapView.showsCompass = (haDict["shows_compass"] != nil)
        mapView.showsScale = (haDict["shows_scale"] != nil)
        mapView.showsTraffic = (haDict["shows_traffic"] != nil)

        mapView.accessibilityIdentifier = "notification_map"

        let span = MKCoordinateSpan(
            latitudeDelta: CLLocationDegrees(templateValue: haDict["latitude_delta"]) ?? 0.1,
            longitudeDelta: CLLocationDegrees(templateValue: haDict["longitude_delta"]) ?? 0.1
        )

        let region = MKCoordinateRegion(center: location, span: span)
        mapView.setRegion(region, animated: true)

        let dropPin = MKPointAnnotation()
        dropPin.coordinate = location

        if let secondLatitude = CLLocationDegrees(templateValue: haDict["second_latitude"]),
           let secondLongitude = CLLocationDegrees(templateValue: haDict["second_longitude"]) {
            let secondDropPin = MKPointAnnotation()
            secondDropPin.coordinate = CLLocationCoordinate2D(latitude: secondLatitude, longitude: secondLongitude)
            secondDropPin.title = L10n.Extensions.Map.Location.new
            mapView.addAnnotation(secondDropPin)

            mapView.selectAnnotation(secondDropPin, animated: true)

            dropPin.title = L10n.Extensions.Map.Location.original
        }

        mapView.addAnnotation(dropPin)

        if mapView.annotations.count > 1 {
            if haDict["shows_line_between_points"] != nil {
                var polylinePoints = [CLLocationCoordinate2D]()

                for annotation in mapView.annotations {
                    polylinePoints.append(annotation.coordinate)
                }
                mapView.addOverlay(MKPolyline(coordinates: &polylinePoints, count: polylinePoints.count))
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

        let pinView = MKPinAnnotationView()
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
