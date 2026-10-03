import MapKit

extension MKMapSnapshotter.Snapshot {
    /// The point for `coordinate` measured from the image's top left corner, which is where the image
    /// renderer's origin is. AppKit measures the snapshot from its bottom left corner.
    func topLeftPoint(for coordinate: CLLocationCoordinate2D) -> CGPoint {
        var point = point(for: coordinate)
        #if os(macOS)
        point.y = image.size.height - point.y
        #endif
        return point
    }
}
