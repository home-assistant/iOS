import CoreLocation
import MapKit
import Shared
import SwiftUI

/// Static, non-interactive map thumbnail for a zone rendered with `MKMapSnapshotter`,
/// with the zone radius drawn as a circle overlay. Much cheaper than a live `MKMapView`
/// when shown for every zone in a scrolling list.
struct ZoneMapSnapshotView: View {
    let coordinate: CLLocationCoordinate2D
    let radius: Double

    @Environment(\.colorScheme) private var colorScheme
    @State private var snapshotImage: UIImage?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let snapshotImage {
                    Image(uiImage: snapshotImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(Color(uiColor: .secondarySystemBackground))
                        .overlay(ProgressView())
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .task(id: SnapshotConfiguration(size: proxy.size, colorScheme: colorScheme)) {
                await generateSnapshot(size: proxy.size)
            }
        }
    }

    private struct SnapshotConfiguration: Equatable {
        let size: CGSize
        let colorScheme: ColorScheme
    }

    private func generateSnapshot(size: CGSize) async {
        guard size.width > 0, size.height > 0 else { return }

        let options = MKMapSnapshotter.Options()
        // Match the interactive zone map: don't zoom in tighter than 400m even for very
        // small zones, so the radius circle stays readable.
        let regionMeters = max(radius * 4, 400)
        options.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: regionMeters,
            longitudinalMeters: regionMeters
        )
        options.size = size
        options.traitCollection = UITraitCollection(userInterfaceStyle: colorScheme == .dark ? .dark : .light)

        do {
            let snapshot = try await MKMapSnapshotter(options: options).start()
            snapshotImage = drawZoneOverlay(on: snapshot, size: size)
        } catch {
            Current.Log.error("Failed to create zone map snapshot: \(error.localizedDescription)")
        }
    }

    private func drawZoneOverlay(on snapshot: MKMapSnapshotter.Snapshot, size: CGSize) -> UIImage {
        let center = snapshot.point(for: coordinate)
        // Project a point on the circle's edge to know the radius in screen points.
        let edgeCoordinate = coordinate.moving(
            distance: .init(value: radius, unit: .meters),
            direction: .init(value: 90, unit: .degrees)
        )
        let pointRadius = abs(snapshot.point(for: edgeCoordinate).x - center.x)
        let zoneColor = UIColor(Color.haPrimary)

        return UIGraphicsImageRenderer(size: size).image { _ in
            snapshot.image.draw(at: .zero)

            let circle = UIBezierPath(ovalIn: CGRect(
                x: center.x - pointRadius,
                y: center.y - pointRadius,
                width: pointRadius * 2,
                height: pointRadius * 2
            ))
            zoneColor.withAlphaComponent(0.2).setFill()
            circle.fill()
            zoneColor.setStroke()
            circle.lineWidth = 2
            circle.stroke()

            let dotRadius: CGFloat = 4
            let dot = UIBezierPath(ovalIn: CGRect(
                x: center.x - dotRadius,
                y: center.y - dotRadius,
                width: dotRadius * 2,
                height: dotRadius * 2
            ))
            zoneColor.setFill()
            dot.fill()
        }
    }
}

#Preview {
    ZoneMapSnapshotView(
        coordinate: .init(latitude: 37.3349, longitude: -122.0090),
        radius: 100
    )
    .frame(height: 150)
}
