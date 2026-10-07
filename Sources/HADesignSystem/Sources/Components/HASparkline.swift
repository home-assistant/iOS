#if !os(watchOS)
import SwiftUI

/// A small trend line with no axes, labels or grid — just the shape of a reading over time.
///
/// Frontend counterpart: `hui-graph-base`, the SVG the sensor card's graph footer and
/// `hui-trend-graph-card-feature` both draw.
///
/// Deliberately not Swift Charts, unlike ``HAHistoryChart``: a sparkline has no axes to format and
/// no time zone to get wrong, and the frontend's smoothing is a specific curve that a chart library
/// would substitute its own for. ``HASparklineGeometry`` reproduces that curve.
public struct HASparkline: View {
    /// `strokeWidth` in the frontend's `data/graph.ts`.
    private static let lineWidth: CGFloat = 2

    private let values: [Double]
    private let color: Color
    private let showsFill: Bool
    private let height: CGFloat

    /// - Parameters:
    ///   - showsFill: Fades the area under the line out downwards, the frontend's gradient fill.
    ///   - height: Explicit, because a line with no intrinsic height collapses when the height
    ///     proposal is unbounded — the same reason ``HAGauge`` takes a diameter.
    public init(
        values: [Double],
        color: Color = .haPrimary,
        showsFill: Bool = true,
        height: CGFloat = 60
    ) {
        self.values = values
        self.color = color
        self.showsFill = showsFill
        self.height = height
    }

    public var body: some View {
        Canvas { context, size in
            // Inset by half the stroke so the line's edges are not clipped at the top and bottom.
            let rect = CGRect(origin: .zero, size: size)
                .insetBy(dx: 0, dy: Self.lineWidth / 2)
            let points = HASparklineGeometry.points(for: values, in: rect)
            guard points.count > 1 else {
                return
            }
            let line = Self.path(through: points)
            if showsFill {
                context.fill(
                    Self.closed(line, in: rect),
                    with: .linearGradient(
                        Gradient(colors: [color.opacity(0.4), color.opacity(0)]),
                        startPoint: CGPoint(x: 0, y: rect.minY),
                        endPoint: CGPoint(x: 0, y: rect.maxY)
                    )
                )
            }
            context.stroke(
                line,
                with: .color(color),
                style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round, lineJoin: .round)
            )
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }

    private static func path(through points: [CGPoint]) -> Path {
        var path = Path()
        path.move(to: points[0])
        for segment in HASparklineGeometry.segments(for: points) {
            path.addQuadCurve(to: segment.end, control: segment.control)
        }
        return path
    }

    /// The line closed down to the baseline, so the area under it can be filled.
    private static func closed(_ line: Path, in rect: CGRect) -> Path {
        var path = line
        guard let last = line.currentPoint else {
            return path
        }
        path.addLine(to: CGPoint(x: last.x, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    VStack(spacing: DesignSystem.Spaces.two) {
        HASparkline(values: [3, 5, 4, 8, 6, 9, 7, 11, 10])
        HASparkline(values: [3, 5, 4, 8, 6, 9, 7, 11, 10], color: .haSuccessColor, showsFill: false)
        HASparkline(values: [7, 7, 7, 7], color: .haWarningColor)
    }
    .padding()
}

extension HASparkline: FrontendComponent {
    public static var frontendComponentName: String { "hui-graph-base" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
