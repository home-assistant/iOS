#if !os(watchOS)
import SwiftUI

/// Concentric rings breaking a total down by level: the inner ring is the top of the tree, each ring
/// out divides the one inside it. The SwiftUI counterpart of the frontend's `ha-sunburst-chart`.
///
/// The angles are worked out in ``HASunburstLayout``; this draws them.
public struct HASunburstChart: View {
    private let segments: [HASunburstSegment]
    private let diameter: CGFloat
    private let showsLabels: Bool

    /// - Parameter diameter: Explicit, as the other radial components' are — rings are shapes with
    ///   no size of their own.
    public init(segments: [HASunburstSegment], diameter: CGFloat = 220, showsLabels: Bool = true) {
        self.segments = segments
        self.diameter = diameter
        self.showsLabels = showsLabels
    }

    public var body: some View {
        let layout = HASunburstLayout(segments: segments)
        // A hole in the middle: without it the innermost ring is a pie, and the eye reads the rings
        // as one filled disc rather than as levels.
        let innerRadius = diameter * 0.15
        let ringThickness = layout.ringCount > 0
            ? (diameter / 2 - innerRadius) / CGFloat(layout.ringCount)
            : 0

        VStack(spacing: DesignSystem.Spaces.one) {
            Canvas { context, size in
                let centre = CGPoint(x: size.width / 2, y: size.height / 2)
                for arc in layout.arcs {
                    let inner = innerRadius + ringThickness * CGFloat(arc.ring)
                    let outer = inner + ringThickness
                    var path = Path()
                    // Angles are measured from twelve o'clock, so each is turned back a quarter
                    // turn from the trigonometric zero that `addArc` uses.
                    let start = Angle.degrees(arc.startAngle.degrees - 90)
                    let end = Angle.degrees(arc.endAngle.degrees - 90)
                    path.addArc(center: centre, radius: outer, startAngle: start, endAngle: end, clockwise: false)
                    path.addArc(center: centre, radius: inner, startAngle: end, endAngle: start, clockwise: true)
                    path.closeSubpath()
                    context.fill(path, with: .color(arc.color))
                    context.stroke(path, with: .color(.haCardBackground), lineWidth: 1)
                }
            }
            .frame(width: diameter, height: diameter)

            if showsLabels {
                FlowLayout(spacing: DesignSystem.Spaces.oneAndHalf) {
                    ForEach(segments) { segment in
                        HStack(spacing: DesignSystem.Spaces.half) {
                            Circle()
                                .fill(segment.color)
                                .frame(width: 8, height: 8)
                            Text(segment.name)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

private let sampleSunburst = [
    HASunburstSegment(id: "heating", name: "Heating", value: 40, color: .haWarningColor, children: [
        HASunburstSegment(id: "living", name: "Living room", value: 25, color: .haWarningColor.opacity(0.7)),
        HASunburstSegment(id: "bedroom", name: "Bedroom", value: 15, color: .haWarningColor.opacity(0.4)),
    ]),
    HASunburstSegment(id: "appliances", name: "Appliances", value: 35, color: .haPrimary, children: [
        HASunburstSegment(id: "washer", name: "Washer", value: 20, color: .haPrimary.opacity(0.7)),
        HASunburstSegment(id: "oven", name: "Oven", value: 15, color: .haPrimary.opacity(0.4)),
    ]),
    HASunburstSegment(id: "lighting", name: "Lighting", value: 25, color: .haSuccessColor),
]

#Preview {
    HASunburstChart(segments: sampleSunburst)
        .padding()
}

extension HASunburstChart: FrontendComponent {
    public static var frontendComponentName: String { "ha-sunburst-chart" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
