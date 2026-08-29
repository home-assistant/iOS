#if !os(watchOS)
import CoreGraphics
import Foundation

/// Turns a run of readings into the curve a sparkline draws.
///
/// Frontend counterpart: `panels/lovelace/common/graph/get-path.ts`, the path builder behind
/// `hui-graph-base`. Split out of ``HASparkline`` for the reason the slider scales are: a plausible
/// squiggle looks right whether or not it is the right squiggle, so the arithmetic is checked apart
/// from the drawing.
public enum HASparklineGeometry {
    /// One smoothed segment: a quadratic curve whose control point is a reading and whose end point
    /// is the midpoint between that reading and the next.
    public struct Segment: Equatable {
        public let control: CGPoint
        public let end: CGPoint
    }

    /// Scales readings into `rect`, oldest at the leading edge, with the highest reading at the top.
    ///
    /// A run whose readings are all equal has no range to scale against; the frontend divides by
    /// that range, so the line is placed at the vertical centre rather than dividing by zero.
    public static func points(for values: [Double], in rect: CGRect) -> [CGPoint] {
        guard !values.isEmpty else {
            return []
        }
        guard values.count > 1 else {
            return [CGPoint(x: rect.midX, y: rect.midY)]
        }
        let lowest = values.min() ?? 0
        let highest = values.max() ?? 0
        let range = highest - lowest
        let step = rect.width / CGFloat(values.count - 1)

        return values.enumerated().map { index, value in
            let fraction = range == 0 ? 0.5 : (value - lowest) / range
            return CGPoint(
                x: rect.minX + CGFloat(index) * step,
                // Flipped: a view's y grows downward, and the highest reading belongs at the top.
                y: rect.maxY - CGFloat(fraction) * rect.height
            )
        }
    }

    /// The curve through those points, matching `getPath` exactly: each reading is a control point
    /// and the curve passes through the midpoints between readings.
    ///
    /// Smoothing this way — rather than by fitting a spline — is what keeps the line from
    /// overshooting past a spike, which matters when the reading is a temperature and the overshoot
    /// would draw a value that was never recorded.
    public static func segments(for points: [CGPoint]) -> [Segment] {
        guard points.count > 1 else {
            return []
        }
        return points.indices.map { index in
            let control = points[index]
            let next = index + 1 < points.count ? points[index + 1] : nil
            let end = next.map { midpoint(control, $0) } ?? control
            return Segment(control: control, end: end)
        }
    }

    private static func midpoint(_ first: CGPoint, _ second: CGPoint) -> CGPoint {
        CGPoint(x: (first.x + second.x) / 2, y: (first.y + second.y) / 2)
    }
}

extension HASparklineGeometry: FrontendComponent {
    public static var frontendComponentName: String { "hui-graph-base" }
}

#endif
