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

@available(iOS 27.0, *)
extension EventLocationCases {
    /// Home Assistant stores a location as a free string, so a structured place is flattened to
    /// its name rather than dropped.
    var plainText: String? {
        switch self {
        case let .text(text): text.nilIfEmpty
        case let .place(place): place.commonName?.nilIfEmpty
        }
    }
}
