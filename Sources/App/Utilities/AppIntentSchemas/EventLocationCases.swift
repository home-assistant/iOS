import AppIntents
import Foundation
import GeoToolbox

/// The union the calendar schema expects for an event's location. Home Assistant stores a plain
/// string, so `.text` is the case it ever produces; the place case exists to satisfy the shape.
@available(iOS 27.0, *)
@UnionValue
enum EventLocationCases {
    case place(PlaceDescriptor)
    case text(String)
}
