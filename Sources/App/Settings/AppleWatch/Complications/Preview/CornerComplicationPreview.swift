import Shared
import SwiftUI

/// iPhone preview of the corner complication, stacked from the watch face corner inward: icon, name,
/// value (more prominent than the name), then the gauge arcing below them all.
struct CornerComplicationPreview: View {
    let context: ComplicationPreviewContext

    // The layout is designed vertically — content stacked on the vertical axis, gauge arc symmetric
    // around 12 o'clock below it — and the whole composition is rotated 45° into the top-trailing
    // corner. That keeps everything centered on the curve by construction.
    private let arcCenter = CGPoint(x: 50, y: 120)
    /// The content stack hugs the corner and grows inward, whatever subset is visible.
    private let stackTop: CGFloat = 10
    private let stackHeight: CGFloat = 52
    private let stackSpacing: CGFloat = 2

    /// Estimated height of the visible icon/name/value stack, so the gauge can hang just below it.
    private var stackContentHeight: CGFloat {
        var heights: [CGFloat] = []
        if context.iconImage != nil { heights.append(20) }
        if context.showsName, !context.name.isEmpty { heights.append(11) }
        if context.showsValue, !context.value.isEmpty { heights.append(17) }
        guard !heights.isEmpty else { return 0 }
        return heights.reduce(0, +) + CGFloat(heights.count - 1) * stackSpacing
    }

    /// The gauge is the innermost element, riding just below whatever the stack shows.
    private var gaugeRadius: CGFloat { arcCenter.y - (stackTop + stackContentHeight + 9) }
    /// Half the sweep (degrees), sized for a roughly constant ~55pt arc whatever the radius.
    private var halfSpan: Double { min(32, 27.5 / gaugeRadius * 180 / .pi) }
    private var startAngle: Double { -90 - halfSpan }
    private var endAngle: Double { -90 + halfSpan }

    var body: some View {
        ZStack {
            if context.showsGauge, let fraction = context.fraction {
                Path { path in
                    path.addArc(
                        center: arcCenter,
                        radius: gaugeRadius,
                        startAngle: .degrees(startAngle),
                        endAngle: .degrees(endAngle),
                        clockwise: false
                    )
                }
                .stroke(context.tint.opacity(0.28), style: StrokeStyle(lineWidth: 6, lineCap: .round))

                Path { path in
                    path.addArc(
                        center: arcCenter,
                        radius: gaugeRadius,
                        startAngle: .degrees(startAngle),
                        endAngle: .degrees(startAngle + (endAngle - startAngle) * fraction),
                        clockwise: false
                    )
                }
                .stroke(context.tint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
            }

            // Corner inward: icon, name, value. The icon is already gated by the "show icon" toggle.
            VStack(spacing: stackSpacing) {
                if let iconImage = context.iconImage {
                    iconImage
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        // Counter the composition's rotation: the icon stays upright, like the
                        // widget's un-curved icon.
                        .rotationEffect(.degrees(-45))
                }
                if context.showsName, !context.name.isEmpty {
                    Text(context.name)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(context.textColor.opacity(0.7))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        // Bound the width so long text scales down instead of clipping off the edge.
                        .frame(maxWidth: 56)
                }
                if context.showsValue, !context.value.isEmpty {
                    Text(context.value)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(context.textColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .frame(maxWidth: 56)
                }
            }
            .frame(height: stackHeight, alignment: .top)
            .position(x: arcCenter.x, y: stackTop + stackHeight / 2)
        }
        .frame(width: 100, height: 100)
        // Designed upright, then swung into the top-trailing corner as one piece.
        .rotationEffect(.degrees(45))
        .environment(\.colorScheme, .dark)
    }
}

#if DEBUG
/// Renders every corner permutation side by side so the layout can be checked at a glance.
private struct CornerVariantsPreview: View {
    let variants: [(String, ComplicationPreviewContext)] = [
        ("Icon + name + value + gauge", .previewCorner()),
        ("Value + name + gauge", .previewCorner(showIcon: false)),
        ("Value + name", .previewCorner(showIcon: false, gauge: false)),
        ("Value only", .previewCorner(showName: false, showIcon: false, gauge: false)),
        ("Name only + gauge", .previewCorner(showValue: false, showIcon: false)),
        ("Icon + gauge", .previewCorner(showValue: false, showName: false)),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spaces.two) {
                ForEach(variants, id: \.0) { label, context in
                    VStack(spacing: DesignSystem.Spaces.one) {
                        CornerComplicationPreview(context: context)
                            .background(Color.black, in: RoundedRectangle(cornerRadius: 12))
                        Text(label).font(.caption)
                    }
                }
            }
            .padding()
        }
    }
}

#Preview("Corner variants") {
    CornerVariantsPreview()
}

#Preview {
    ScrollView {
        VStack(spacing: DesignSystem.Spaces.three) {
            AllFamiliesComplicationPreview(
                config: WatchComplicationConfig(serverId: "preview"),
                server: ServerFixture.standard,
                selectedFamily: .constant(.circular)
            )

            AllFamiliesComplicationPreview(
                config: {
                    var config = WatchComplicationConfig(
                        serverId: "preview",
                        name: "Solar",
                        iconName: "solar-power",
                        iconColor: "#FFD60AFF"
                    )
                    config.setOptions(
                        WatchComplicationConfig.FamilyOptions(
                            showIcon: true,
                            showMin: false,
                            showMax: false,
                            tint: "#FFD60AFF",
                            gaugeStyle: WatchComplicationConfig.GaugeStyle.capacity.rawValue
                        ),
                        for: .circular
                    )
                    config.setOptions(
                        WatchComplicationConfig.FamilyOptions(tint: "#FFD60AFF"),
                        for: .corner
                    )
                    return config
                }(),
                server: ServerFixture.standard,
                selectedFamily: .constant(.corner)
            )

            AllFamiliesComplicationPreview(
                config: {
                    var config = WatchComplicationConfig(
                        serverId: "preview",
                        name: "Humidity",
                        iconName: "water-percent",
                        iconColor: "#64D2FFFF"
                    )
                    for family in WatchComplicationConfig.Family.allCases {
                        config.setOptions(
                            WatchComplicationConfig.FamilyOptions(showGauge: false, tint: "#64D2FFFF"),
                            for: family
                        )
                    }
                    return config
                }(),
                server: ServerFixture.standard,
                selectedFamily: .constant(.rectangular)
            )
        }
        .padding()
    }
}
#endif
