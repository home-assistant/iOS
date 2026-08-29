#if !os(watchOS)
import Foundation
import SwiftUI

/// A slice of an ``HASunburstChart``, and the slices nested inside it.
///
/// A segment's own `value` is what it is worth in its parent's ring. Children need not add up to it:
/// they share whatever span their parent got, in proportion to each other. So a breakdown that is
/// short of its parent still fills the parent's wedge rather than leaving a gap — what it cannot do
/// is spill past the parent and distort the ring outside it.
///
/// Frontend counterpart: the data `chart/ha-sunburst-chart` is handed, rather than an element of
/// its own.
public struct HASunburstSegment: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let value: Double
    public let color: Color
    public let children: [HASunburstSegment]

    public init(
        id: String,
        name: String,
        value: Double,
        color: Color = .haPrimary,
        children: [HASunburstSegment] = []
    ) {
        self.id = id
        self.name = name
        self.value = value
        self.color = color
        self.children = children
    }
}

extension HASunburstSegment: FrontendComponent {
    public static var frontendComponentName: String { "ha-sunburst-chart" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
