#if !os(watchOS)
import Foundation
import SwiftUI

/// Flattens a sunburst's tree into the arcs to draw: one ring per depth, each segment spanning the
/// share of its parent's angle that its value is worth.
///
/// Split out of ``HASunburstChart`` for the reason the sankey's layout is: whether the slices add up
/// is arithmetic, and a ring of plausible wedges looks right either way.
///
/// Frontend counterpart: the angle maths inside `chart/ha-sunburst-chart`, which keeps it in the
/// element rather than apart from it.
public struct HASunburstLayout {
    /// One wedge: which ring it belongs to and the angles it spans, measured clockwise from twelve
    /// o'clock.
    public struct Arc: Equatable {
        public let id: String
        public let name: String
        public let color: Color
        /// 0 is the innermost ring.
        public let ring: Int
        public let startAngle: Angle
        public let endAngle: Angle
    }

    public let arcs: [Arc]
    /// How many rings deep the tree goes, so the chart knows how thick to make each.
    public let ringCount: Int

    public init(segments: [HASunburstSegment]) {
        var arcs: [Arc] = []
        var deepestRing = 0

        func place(_ segments: [HASunburstSegment], ring: Int, from: Angle, to: Angle) {
            let usable = segments.filter { $0.value > 0 }
            let total = usable.reduce(0) { $0 + $1.value }
            guard total > 0, to.degrees > from.degrees else { return }
            deepestRing = Swift.max(deepestRing, ring)

            var cursor = from
            let span = to.degrees - from.degrees
            for segment in usable {
                let end = Angle.degrees(cursor.degrees + span * (segment.value / total))
                arcs.append(
                    Arc(
                        id: segment.id,
                        name: segment.name,
                        color: segment.color,
                        ring: ring,
                        startAngle: cursor,
                        endAngle: end
                    )
                )
                // Children divide their parent's wedge, not the whole circle, which is what makes a
                // sunburst read as a breakdown rather than as unrelated rings.
                place(segment.children, ring: ring + 1, from: cursor, to: end)
                cursor = end
            }
        }

        place(segments, ring: 0, from: .degrees(0), to: .degrees(360))
        self.arcs = arcs
        self.ringCount = arcs.isEmpty ? 0 : deepestRing + 1
    }
}

extension HASunburstLayout: FrontendComponent {
    public static var frontendComponentName: String { "ha-sunburst-chart" }
}

#endif
