import MapKit
import RealmSwift
import Shared
import SwiftUI
import UIKit

private class RegionCircle: MKCircle {}
private class ZoneCircle: MKCircle {}
private class GPSCircle: MKCircle {}

struct LocationHistoryDetailViewControllerWrapper: UIViewControllerRepresentable {
    private var currentEntry: LocationHistoryEntry

    class Coordinator {
        var parentObserver: NSKeyValueObservation?
        var titleObsserver: NSKeyValueObservation?
    }

    func makeUIViewController(context: Context) -> LocationHistoryDetailViewController {
        let viewController = LocationHistoryDetailViewController(currentEntry: currentEntry)
        context.coordinator.parentObserver = viewController.observe(\.parent) { vc, _ in
            vc.parent?.title = vc.title
            vc.parent?.navigationItem.title = vc.navigationItem.title
            vc.parent?.navigationItem.rightBarButtonItems = vc.navigationItem.rightBarButtonItems
            vc.parent?.toolbarItems = vc.toolbarItems
        }
        context.coordinator.titleObsserver = viewController.observe(\.title) { vc, _ in
            vc.parent?.title = vc.title
            vc.parent?.navigationItem.title = vc.navigationItem.title
        }
        return viewController
    }

    func updateUIViewController(_ uiViewController: LocationHistoryDetailViewController, context: Context) {}

    func makeCoordinator() -> Self.Coordinator { Coordinator() }

    init(currentEntry: LocationHistoryEntry) {
        self.currentEntry = currentEntry
    }
}

final class LocationHistoryDetailViewController: UIViewController {
    var onDismissCallback: ((UIViewController) -> Void)?

    enum MoveDirection {
        case up, down
    }

    private var currentEntry: LocationHistoryEntry {
        didSet {
            setUp()
            updateOverlays()
            updateAnnotations()
            center(self)
            updateButtons()
        }
    }

    private var locationHistoryEntries: [LocationHistoryEntry] = []
    private var token: NotificationToken?
    private let map = MKMapView()

    init(currentEntry: LocationHistoryEntry) {
        self.currentEntry = currentEntry
        super.init(nibName: nil, bundle: nil)
        setUp()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    deinit {
        token?.invalidate()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        onDismissCallback?(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        navigationController?.setToolbarHidden(false, animated: animated)
    }

    private func setUp() {
        setUpObserver()
        title = DateFormatter.localizedString(
            from: currentEntry.CreatedAt,
            dateStyle: .short,
            timeStyle: .medium
        )
        navigationItem.title = title
    }

    private func setUpObserver() {
        let results = Current.realm()
            .objects(LocationHistoryEntry.self)
            .sorted(byKeyPath: "CreatedAt", ascending: false)

        token = results.observe { [weak self] _ in
            self?.locationHistoryEntries = results.map(LocationHistoryEntry.init)
        }
    }

    @objc private func center(_ sender: AnyObject?) {
        map.setRegion(
            .init(
                center: currentEntry.clLocation.coordinate,
                latitudinalMeters: 300,
                longitudinalMeters: 300
            ),
            animated: sender != nil
        )
    }

    private func report() -> String {
        var value = "# Debug Information\n\n"

        let accuracyNote: String

        if currentEntry.Accuracy == 65 {
            accuracyNote = " (from Wi-Fi)"
        } else if currentEntry.Accuracy == 1414 {
            accuracyNote = " (from cell tower)"
        } else {
            accuracyNote = ""
        }

        let accuracyAuthorization: String

        if let authorization = currentEntry.accuracyAuthorization {
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
            \(currentEntry.Payload)
            ```

            ## Location
            - Trigger: \(currentEntry.Trigger ?? "(unknown)")
            - Center: (\(latLongString(currentEntry.Latitude)), \(latLongString(currentEntry.Longitude)))
            - Accuracy: \(distanceString(currentEntry.Accuracy))\(accuracyNote)
            - Accuracy Authorization: \(accuracyAuthorization)

            ## Regions
            """ + "\n"
        )

        let allRegions = Current.realm().objects(RLMZone.self)
            .flatMap(\.circularRegionsForMonitoring)
            .sorted(by: { a, b in
                a.distanceWithAccuracy(from: currentEntry.clLocation) < b
                    .distanceWithAccuracy(from: currentEntry.clLocation)
            })
        for region in allRegions {
            let regionLocation = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)
            let distanceWithoutAccuracy = regionLocation.distance(from: currentEntry.clLocation)
            let distanceWithAccuracy = region.distanceWithAccuracy(from: currentEntry.clLocation)
            let contains = region.containsWithAccuracy(currentEntry.clLocation)

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
        move(.up)
    }

    @objc private func moveDown(_ sender: AnyObject?) {
        move(.down)
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

        upItem?.isEnabled = canMove(.up)
        downItem?.isEnabled = canMove(.down)
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
            with(AppConstants.helpBarButtonItem) {
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

        map.pointOfInterestFilter = .excludingAll
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

        updateOverlays()
        updateAnnotations()

        center(nil)
        updateButtons()
    }

    func updateOverlays() {
        map.removeOverlays(map.overlays)
        map.addOverlays(Self.overlays(for: Current.realm().objects(RLMZone.self)))
        map.addOverlays(Self.overlays(for: currentEntry.clLocation))
    }

    func updateAnnotations() {
        map.removeAnnotations(map.annotations)
        map.addAnnotations(Self.annotations(for: currentEntry.clLocation))
    }
}

private extension LocationHistoryDetailViewController {
    func canMove(
        _ direction: LocationHistoryDetailViewController.MoveDirection
    ) -> Bool {
        switch direction {
        case .up:
            locationHistoryEntries.first?.CreatedAt != currentEntry.CreatedAt
        case .down:
            locationHistoryEntries.last?.CreatedAt != currentEntry.CreatedAt
        }
    }

    func move(
        _ direction: LocationHistoryDetailViewController.MoveDirection
    ) {
        guard
            let currentIndex = locationHistoryEntries.firstIndex(where: { entry in
                entry.CreatedAt == currentEntry.CreatedAt
            }) else { return }
        let newIndex = switch direction {
        case .up: currentIndex - 1
        case .down: currentIndex + 1
        }

        guard let newEntry = locationHistoryEntries[safe: newIndex] else { return }
        currentEntry = newEntry
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
                renderer.fillColor = AppConstants.tintColor.withAlphaComponent(0.75)
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
