import MapKit
import SwiftUI

struct NotificationMapPin: Identifiable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let tint: Color
}
