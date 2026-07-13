import MapKit
import SwiftUI

struct NotificationMapPin: Identifiable {
    let coordinate: CLLocationCoordinate2D
    let tint: Color

    var id: String {
        "\(coordinate.latitude),\(coordinate.longitude)"
    }
}
