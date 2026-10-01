#if os(macOS)
import MapKit
import Shared
import SwiftUI

/// The map behind a location history entry on the Mac: the entry's position and accuracy, over every zone
/// and the regions the app monitors for it.
struct LocationHistoryMapView: NSViewRepresentable {
    /// The zone as the server defines it.
    private final class ZoneCircle: MKCircle {}
    /// One of the regions monitored in place of a zone too small to monitor on its own.
    private final class RegionCircle: MKCircle {}
    /// The accuracy of the entry's position.
    private final class GPSCircle: MKCircle {}

    let entry: LocationHistoryEntry
    /// Created by the screen that shows the map, so its toolbar can recenter and share it.
    let coordinator: Coordinator

    func makeCoordinator() -> Coordinator {
        coordinator
    }

    func makeNSView(context: Context) -> MKMapView {
        // A size to frame the first region in; the map is laid out to its real one right after.
        let mapView = MKMapView(frame: CGRect(x: 0, y: 0, width: 600, height: 400))
        mapView.pointOfInterestFilter = .excludingAll
        mapView.showsBuildings = true
        mapView.showsCompass = false
        mapView.showsTraffic = false
        mapView.showsUserLocation = false
        mapView.showsScale = false
        mapView.delegate = context.coordinator
        context.coordinator.mapView = mapView
        context.coordinator.show(entry, animated: false)
        return mapView
    }

    func updateNSView(_ nsView: MKMapView, context: Context) {
        guard context.coordinator.entry != entry else { return }
        context.coordinator.show(entry, animated: true)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        fileprivate weak var mapView: MKMapView?
        fileprivate var entry: LocationHistoryEntry?
        private var snapshotter: MKMapSnapshotter?

        /// Brings the entry back to the middle of the map.
        func center(animated: Bool) {
            guard let mapView, let entry else { return }
            mapView.setRegion(
                .init(
                    center: entry.clLocation.coordinate,
                    latitudinalMeters: 300,
                    longitudinalMeters: 300
                ),
                animated: animated
            )
        }

        /// Offers a picture of the map as it is framed now, together with `report`, to the sharing
        /// services.
        func share(report: String) {
            guard let mapView, let entry, mapView.bounds.width > 0, mapView.bounds.height > 0 else { return }

            let options = MKMapSnapshotter.Options()
            options.region = mapView.region
            options.size = mapView.bounds.size
            options.pointOfInterestFilter = .excludingAll
            options.appearance = mapView.effectiveAppearance

            let circles = mapView.overlays.compactMap { $0 as? MKCircle }
            let pin = entry.clLocation.coordinate
            let snapshotter = MKMapSnapshotter(options: options)
            // Kept until it finishes: nothing else holds on to it while it renders.
            self.snapshotter = snapshotter
            snapshotter.start { [weak self] snapshot, error in
                guard let self, let mapView = self.mapView else { return }
                self.snapshotter = nil

                var items: [Any] = [report]
                if let snapshot {
                    items.insert(Self.image(of: snapshot, circles: circles, pin: pin), at: 0)
                } else {
                    Current.Log.error("couldn't take a picture of the location history map: \(error.debugDescription)")
                }

                // Anchored to the top trailing corner, under the toolbar button that asked for it.
                let bounds = mapView.bounds
                let top = mapView.isFlipped ? bounds.minY : bounds.maxY - 1
                let anchor = CGRect(x: bounds.maxX - 1, y: top, width: 1, height: 1)
                NSSharingServicePicker(items: items).show(relativeTo: anchor, of: mapView, preferredEdge: .minY)
            }
        }

        fileprivate func show(_ entry: LocationHistoryEntry, animated: Bool) {
            guard let mapView else { return }
            self.entry = entry

            mapView.removeOverlays(mapView.overlays)
            mapView.addOverlays(AppZone.all().flatMap { zone -> [MKOverlay] in
                var overlays = [MKOverlay]()

                let regions = zone.circularRegionsForMonitoring
                if regions.count > 1 {
                    // for non-single-region zones, show the <100m as well
                    overlays.append(contentsOf: regions.map { RegionCircle(center: $0.center, radius: $0.radius) })
                }

                overlays.append(ZoneCircle(center: zone.center, radius: zone.radius))
                return overlays
            })
            mapView.addOverlay(GPSCircle(
                center: entry.clLocation.coordinate,
                radius: entry.clLocation.horizontalAccuracy
            ))

            mapView.removeAnnotations(mapView.annotations)
            mapView.addAnnotation(with(MKPointAnnotation()) {
                $0.coordinate = entry.clLocation.coordinate
            })

            center(animated: animated)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: nil)
            view.markerTintColor = .purple
            return view
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let circle = overlay as? MKCircle else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let renderer = MKCircleRenderer(circle: circle)
            renderer.fillColor = Self.fillColor(for: circle)
            return renderer
        }

        private static func fillColor(for circle: MKCircle) -> UIColor? {
            switch circle {
            case is ZoneCircle: return AppConstants.tintColor.withAlphaComponent(0.75)
            case is RegionCircle: return UIColor.orange.withAlphaComponent(0.25)
            case is GPSCircle: return UIColor.purple.withAlphaComponent(0.75)
            default: return nil
            }
        }

        /// The snapshot with the circles and the entry's position drawn over it. A snapshot has the map
        /// alone, so what the map view adds on top is drawn again here.
        private static func image(
            of snapshot: MKMapSnapshotter.Snapshot,
            circles: [MKCircle],
            pin: CLLocationCoordinate2D
        ) -> UIImage {
            let size = snapshot.image.size
            return UIGraphicsImageRenderer(size: size).image { _ in
                snapshot.image.draw(
                    in: CGRect(origin: .zero, size: size),
                    from: .zero,
                    operation: .sourceOver,
                    fraction: 1,
                    respectFlipped: true,
                    hints: nil
                )

                for circle in circles {
                    guard let color = fillColor(for: circle) else { continue }
                    let center = snapshot.topLeftPoint(for: circle.coordinate)
                    // Project a point on the circle's edge to know the radius in points.
                    let edge = snapshot.topLeftPoint(for: circle.coordinate.moving(
                        distance: .init(value: circle.radius, unit: .meters),
                        direction: .init(value: 90, unit: .degrees)
                    ))
                    let radius = abs(edge.x - center.x)
                    color.setFill()
                    UIBezierPath(ovalIn: CGRect(
                        x: center.x - radius,
                        y: center.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )).fill()
                }

                let position = snapshot.topLeftPoint(for: pin)
                let dotRadius: CGFloat = 6
                let dot = UIBezierPath(ovalIn: CGRect(
                    x: position.x - dotRadius,
                    y: position.y - dotRadius,
                    width: dotRadius * 2,
                    height: dotRadius * 2
                ))
                UIColor.purple.setFill()
                dot.fill()
                UIColor.white.setStroke()
                dot.lineWidth = 2
                dot.stroke()
            }
        }
    }
}

#Preview {
    LocationHistoryMapView(
        entry: LocationHistoryEntry(
            updateType: .Manual,
            location: .init(latitude: 41.1234, longitude: 52.2),
            zone: nil,
            accuracyAuthorization: .fullAccuracy,
            payload: "payload"
        ),
        coordinator: .init()
    )
}
#endif
