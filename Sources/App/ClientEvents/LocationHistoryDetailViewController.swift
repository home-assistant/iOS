import MapKit
import RealmSwift
import Shared
import UIKit

private class RegionCircle: MKCircle {}
private class ZoneCircle: MKCircle {}
private class GPSCircle: MKCircle {}

class LocationHistoryDetailViewController: UIViewController {
    let entry: LocationHistoryEntry
    private let map = MKMapView()

    init(entry: LocationHistoryEntry) {
        self.entry = entry
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    @objc private func center(_ sender: AnyObject?) {
        map.setRegion(
            .init(
                center: entry.clLocation.coordinate,
                latitudinalMeters: 300,
                longitudinalMeters: 300
            ),
            animated: sender != nil
        )
    }

    private func report() -> String {
        var value = ""

        value.append("location\n--------\n")
        value.append("""
            latitude: \(entry.Latitude)
            longitude: \(entry.Longitude)
            accuracy: \(entry.Accuracy)
            ^ note: accuracy of 65m is from Wi-Fi, 1414m is is from cell tower
        """)
        value.append("\n\n")

        value.append("regions\n-------\n")

        let allRegions = Current.realm().objects(RLMZone.self)
            .flatMap(\.circularRegionsForMonitoring)
        for region in allRegions {
            let regionLocation = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)
            let distance = regionLocation.distance(from: entry.clLocation)
            let contains = distance <= (region.radius + entry.Accuracy)

            value.append("""
                \(region.identifier): (\(region.center.latitude), \(region.center.longitude)) \(region.radius)m
                \(String(format: "%.02lf", distance))m away, \(contains ? "inside" : "outside")
            """)

            value.append("\n\n")
        }

        return value
    }

    @objc private func help(_ sender: AnyObject?) {
        let alert = UIAlertController(
            title: nil,
            message: L10n.Settings.LocationHistory.Detail.explanation,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.cancelLabel, style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    @objc private func share(_ sender: AnyObject?) {
        let bounds = CGRect(x: 0, y: 0, width: map.bounds.width, height: map.bounds.height)
        let snapshot = UIGraphicsImageRenderer(bounds: bounds).image { _ in
            map.drawHierarchy(in: bounds, afterScreenUpdates: true)
        }

        let controller = UIActivityViewController(activityItems: [snapshot, report()], applicationActivities: nil)
        present(controller, animated: true, completion: nil)
    }

    private static func overlays<T: Collection>(for zones: T) -> [MKOverlay] where T.Element: RLMZone {
        zones.flatMap { zone -> [MKOverlay] in
            var overlays = [MKOverlay]()

            let regions = zone.circularRegionsForMonitoring
            if regions.count > 1 {
                // for non-single-region zones, show the <100m as well
                overlays.append(contentsOf: regions.map { RegionCircle(center: $0.center, radius: $0.radius) })
            }

            overlays.append(ZoneCircle(center: zone.center, radius: zone.Radius))
            return overlays
        }
    }

    private static func overlays(for location: CLLocation) -> [MKOverlay] {
        [
            GPSCircle(center: location.coordinate, radius: location.horizontalAccuracy),
        ]
    }

    private static func annotations(for location: CLLocation) -> [MKAnnotation] {
        [
            with(MKPointAnnotation()) {
                $0.coordinate = location.coordinate
            },
        ]
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(
                image: MaterialDesignIcons.crosshairsGpsIcon.image(ofSize: CGSize(width: 30, height: 30), color: nil),
                style: .plain,
                target: self,
                action: #selector(center(_:))
            ),
            with(Constants.helpBarButtonItem) {
                $0.target = self
                $0.action = #selector(help(_:))
            },
            UIBarButtonItem(
                image: MaterialDesignIcons.exportVariantIcon.image(ofSize: CGSize(width: 30, height: 30), color: nil),
                style: .plain,
                target: self,
                action: #selector(share(_:))
            ),
        ]

        if #available(iOS 13, *) {
            map.pointOfInterestFilter = .excludingAll
        } else {
            map.showsPointsOfInterest = false
        }

        map.showsBuildings = true
        map.showsCompass = false
        map.showsTraffic = false
        map.showsUserLocation = false
        map.showsScale = false

        map.delegate = self
        map.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(map)
        NSLayoutConstraint.activate([
            map.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            map.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            map.topAnchor.constraint(equalTo: view.topAnchor),
            map.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        map.addOverlays(Self.overlays(for: Current.realm().objects(RLMZone.self)))
        map.addOverlays(Self.overlays(for: entry.clLocation))
        map.addAnnotations(Self.annotations(for: entry.clLocation))

        center(nil)
    }
}

extension LocationHistoryDetailViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let view = MKPinAnnotationView(annotation: annotation, reuseIdentifier: nil)
        view.pinTintColor = .purple
        return view
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let overlay = overlay as? MKCircle {
            let renderer = MKCircleRenderer(circle: overlay)

            switch overlay {
            case is ZoneCircle:
                renderer.fillColor = Constants.tintColor
            case is RegionCircle:
                renderer.fillColor = UIColor.orange.withAlphaComponent(0.25)
            case is GPSCircle:
                renderer.fillColor = UIColor.purple.withAlphaComponent(0.75)
            default: break
            }

            return renderer
        } else {
            fatalError()
        }
    }
}
