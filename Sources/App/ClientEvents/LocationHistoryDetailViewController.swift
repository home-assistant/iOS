import Eureka
import MapKit
import RealmSwift
import Shared
import UIKit

protocol LocationHistoryDetailMoveDelegate: AnyObject {
    func detail(
        _ controller: LocationHistoryDetailViewController,
        canMove direction: LocationHistoryDetailViewController.MoveDirection
    ) -> Bool
    func detail(
        _ controller: LocationHistoryDetailViewController,
        move direction: LocationHistoryDetailViewController.MoveDirection
    )
}

private class RegionCircle: MKCircle {}
private class ZoneCircle: MKCircle {}
private class GPSCircle: MKCircle {}

final class LocationHistoryDetailViewController: UIViewController, TypedRowControllerType {
    typealias RowValue = LocationHistoryDetailViewController
    var row: RowOf<RowValue>!
    var onDismissCallback: ((UIViewController) -> Void)?

    enum MoveDirection {
        case up, down
    }

    weak var moveDelegate: LocationHistoryDetailMoveDelegate? {
        didSet {
            updateButtons()
        }
    }

    let entry: LocationHistoryEntry
    private let map = MKMapView()

    init(entry: LocationHistoryEntry) {
        self.entry = entry
        super.init(nibName: nil, bundle: nil)
        title = DateFormatter.localizedString(
            from: entry.CreatedAt,
            dateStyle: .short,
            timeStyle: .medium
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        onDismissCallback?(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setToolbarHidden(false, animated: animated)
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
        var value = "# Debug Information\n\n"

        let accuracyNote: String

        if entry.Accuracy == 65 {
            accuracyNote = " (from Wi-Fi)"
        } else if entry.Accuracy == 1414 {
            accuracyNote = " (from cell tower)"
        } else {
            accuracyNote = ""
        }

        let accuracyAuthorization: String

        if let authorization = entry.accuracyAuthorization {
            switch authorization {
            case .fullAccuracy: accuracyAuthorization = "full"
            case .reducedAccuracy: accuracyAuthorization = "reduced"
            @unknown default: accuracyAuthorization = "unknown"
            }
        } else {
            accuracyAuthorization = "missing"
        }

        func latLongString(_ value: Double) -> String {
            String(format: "%.06lf", value)
        }

        func distanceString(_ value: Double) -> String {
            String(format: "%04.02lfm", max(0, value))
        }

        value.append(
            """
            ## Payload
            ```json
            \(entry.Payload)
            ```

            ## Location
            - Trigger: \(entry.Trigger ?? "(unknown)")
            - Center: (\(latLongString(entry.Latitude)), \(latLongString(entry.Longitude)))
            - Accuracy: \(distanceString(entry.Accuracy))\(accuracyNote)
            - Accuracy Authorization: \(accuracyAuthorization)

            ## Regions
            """ + "\n"
        )

        let allRegions = Current.realm().objects(RLMZone.self)
            .flatMap(\.circularRegionsForMonitoring)
            .sorted(by: { a, b in
                a.distanceWithAccuracy(from: entry.clLocation) < b.distanceWithAccuracy(from: entry.clLocation)
            })
        for region in allRegions {
            let regionLocation = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)
            let distanceWithoutAccuracy = regionLocation.distance(from: entry.clLocation)
            let distanceWithAccuracy = region.distanceWithAccuracy(from: entry.clLocation)
            let contains = region.containsWithAccuracy(entry.clLocation)

            value.append(
                """
                ### \(region.identifier)
                - Center: (\(latLongString(region.center.latitude)), \(latLongString(region.center.longitude)))
                - Radius: \(distanceString(region.radius))
                - Distance From Perimeter: \(distanceString(distanceWithAccuracy))
                - Distance From Center: \(distanceString(distanceWithoutAccuracy))
                - Relative State: \(contains ? "inside" : "outside")
                """
            )

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
        alert.addAction(UIAlertAction(title: L10n.okLabel, style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }

    @objc private func share(_ sender: UIBarButtonItem?) {
        let bounds = CGRect(x: 0, y: 0, width: map.bounds.width, height: map.bounds.height)
        let snapshot = UIGraphicsImageRenderer(bounds: bounds).image { _ in
            map.drawHierarchy(in: bounds, afterScreenUpdates: true)
        }

        let controller = UIActivityViewController(activityItems: [snapshot, report()], applicationActivities: nil)
        with(controller.popoverPresentationController) {
            $0?.barButtonItem = sender
        }
        present(controller, animated: true, completion: nil)
    }

    @objc private func moveUp(_ sender: AnyObject?) {
        moveDelegate?.detail(self, move: .up)
    }

    @objc private func moveDown(_ sender: AnyObject?) {
        moveDelegate?.detail(self, move: .down)
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

    private func updateButtons() {
        let upItem = navigationItem.rightBarButtonItems?.first(where: { $0.action == #selector(moveUp(_:)) })
        let downItem = navigationItem.rightBarButtonItems?.first(where: { $0.action == #selector(moveDown(_:)) })

        upItem?.isEnabled = moveDelegate?.detail(self, canMove: .up) ?? false
        downItem?.isEnabled = moveDelegate?.detail(self, canMove: .down) ?? false
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(
                icon: .arrowDownIcon,
                target: self,
                action: #selector(moveDown(_:))
            ),
            UIBarButtonItem(
                icon: .arrowUpIcon,
                target: self,
                action: #selector(moveUp(_:))
            ),
        ]

        setToolbarItems([
            UIBarButtonItem(
                icon: .crosshairsGpsIcon,
                target: self,
                action: #selector(center(_:))
            ),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            with(Constants.helpBarButtonItem) {
                $0.target = self
                $0.action = #selector(help(_:))
            },
            with(UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)) {
                $0.width = 20
            },
            UIBarButtonItem(
                icon: .exportVariantIcon,
                target: self,
                action: #selector(share(_:))
            ),
        ], animated: false)

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
        updateButtons()
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
                renderer.fillColor = Constants.tintColor.withAlphaComponent(0.75)
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
