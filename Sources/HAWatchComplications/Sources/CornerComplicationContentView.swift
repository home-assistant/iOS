import SwiftUI
import UIKit

/// The iPhone-side (and snapshot) rendering of the corner complication, stacked from the watch face
/// corner inward: icon, name, value (more prominent than the name), then the gauge arcing below them.
///
/// The real watch complication (`CornerComplicationView`) renders via the native
/// `widgetCurvesContent()` / `widgetLabel` APIs, which only work inside a widget host — so this view is
/// the shared approximation used by the in-app editor preview (`CornerComplicationPreview`) and the
/// snapshot tests. Both sides resolve their text / gauge through `CornerComplicationRenderModel`.
@available(iOS 16.0, watchOS 10.0, *)
public struct CornerComplicationContentView: View {
    public let model: CornerComplicationRenderModel

    public init(model: CornerComplicationRenderModel) {
        self.model = model
    }

    // The layout is designed vertically — content stacked on the vertical axis, gauge arc symmetric
    // around 12 o'clock below it — and the whole composition is rotated 45° into the top-trailing
    // corner. That keeps everything centered on the curve by construction.
    private let arcCenter = CGPoint(x: 50, y: 120)
    /// The content stack hugs the corner and grows inward, whatever subset is visible.
    private let stackTop: CGFloat = 10
    private let stackHeight: CGFloat = 52
    private let stackSpacing: CGFloat = 2
    private let iconSize: CGFloat = 20
    private let nameHeight: CGFloat = 11
    private let curvedValueHeight: CGFloat = 17
    private let flatValueHeight: CGFloat = 24
    private let gaugeInset: CGFloat = 9
    private let maxTextWidth: CGFloat = 56
    private let arcLineWidth: CGFloat = 6
    private let arcTrackOpacity: CGFloat = 0.28
    private let nameTextOpacity: CGFloat = 0.7

    private var showsIcon: Bool { model.iconImage != nil }
    private var showsName: Bool { model.showsName && !model.title.isEmpty }
    private var showsValue: Bool { model.showsValue && !model.valueText.isEmpty }

    /// The value's line: the flat (legacy outer-text) variant is set larger than the curved one.
    private var valueHeight: CGFloat { model.curvesText ? curvedValueHeight : flatValueHeight }
    private var valueFont: Font {
        model.curvesText
            ? .system(size: 14, weight: .bold, design: .rounded)
            : CornerComplicationTypography.flatTextFont
    }

    /// Estimated height of the visible icon/name/value stack, so the gauge can hang just below it.
    private var stackContentHeight: CGFloat {
        var heights: [CGFloat] = []
        if showsIcon { heights.append(iconSize) }
        if showsName { heights.append(nameHeight) }
        if showsValue { heights.append(valueHeight) }
        guard !heights.isEmpty else { return 0 }
        return heights.reduce(0, +) + CGFloat(heights.count - 1) * stackSpacing
    }

    /// The gauge is the innermost element, riding just below whatever the stack shows.
    private var gaugeRadius: CGFloat { arcCenter.y - (stackTop + stackContentHeight + gaugeInset) }
    /// Half the sweep (degrees), sized for a roughly constant ~55pt arc whatever the radius.
    private var halfSpan: Double { min(32, 27.5 / gaugeRadius * 180 / .pi) }
    private var startAngle: Double { -90 - halfSpan }
    private var endAngle: Double { -90 + halfSpan }

    public var body: some View {
        let textColor = model.textColor ?? .primary
        ZStack {
            if let fraction = model.fraction {
                Path { path in
                    path.addArc(
                        center: arcCenter,
                        radius: gaugeRadius,
                        startAngle: .degrees(startAngle),
                        endAngle: .degrees(endAngle),
                        clockwise: false
                    )
                }
                .stroke(
                    model.tint.opacity(arcTrackOpacity),
                    style: StrokeStyle(lineWidth: arcLineWidth, lineCap: .round)
                )

                Path { path in
                    path.addArc(
                        center: arcCenter,
                        radius: gaugeRadius,
                        startAngle: .degrees(startAngle),
                        endAngle: .degrees(startAngle + (endAngle - startAngle) * fraction),
                        clockwise: false
                    )
                }
                .stroke(model.tint, style: StrokeStyle(lineWidth: arcLineWidth, lineCap: .round))
            }

            // Corner inward: icon, name, value.
            VStack(spacing: stackSpacing) {
                if showsIcon, let iconImage = model.iconImage {
                    iconImage
                        .resizable()
                        .scaledToFit()
                        .frame(width: iconSize, height: iconSize)
                        // Counter the composition's rotation: the icon stays upright, like the
                        // widget's un-curved icon.
                        .rotationEffect(.degrees(-45))
                }
                if showsName {
                    Text(model.title)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(textColor.opacity(nameTextOpacity))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        // Bound the width so long text scales down instead of clipping off the edge.
                        .frame(maxWidth: maxTextWidth)
                }
                if showsValue {
                    Text(model.valueText)
                        .font(valueFont)
                        .foregroundStyle(textColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .frame(maxWidth: maxTextWidth)
                        // Flat text is drawn upright by the widget (only curved text follows the
                        // bezel), so counter the composition's rotation the way the icon does.
                        .rotationEffect(.degrees(model.curvesText ? 0 : -45))
                }
            }
            .frame(height: stackHeight, alignment: .top)
            .position(x: arcCenter.x, y: stackTop + stackHeight / 2)
        }
        .frame(width: 100, height: 100)
        // Designed upright, then swung into the top-trailing corner as one piece.
        .rotationEffect(.degrees(45))
    }
}

#if DEBUG
@available(iOS 16.0, watchOS 10.0, *)
public extension CornerComplicationRenderModel {
    /// Sample model for previews and snapshot tests, with independently toggleable slots.
    static func sample(
        icon: Bool = true,
        value: String = "68%",
        showValue: Bool = true,
        title: String? = "Battery",
        fraction: Double? = 0.68,
        tint: Color = .green,
        textColor: Color? = nil,
        curvesText: Bool = true
    ) -> CornerComplicationRenderModel {
        CornerComplicationRenderModel(
            iconImage: icon ? sampleBoltIcon() : nil,
            title: title ?? "",
            showsName: title != nil,
            valueText: value,
            showsValue: showValue,
            fraction: fraction,
            tint: tint,
            textColor: textColor,
            curvesText: curvesText
        )
    }
}

/// A white template symbol for the sample icon slot. Built via `UIImage(systemName:)` rather than the
/// SwiftUI symbol initializer, to keep this lean package free of an SFSafeSymbols dependency.
private func sampleBoltIcon() -> Image {
    Image(uiImage: (UIImage(systemName: "bolt.fill") ?? UIImage()).withRenderingMode(.alwaysTemplate))
}

@available(iOS 16.0, watchOS 10.0, *)
private func face(_ model: CornerComplicationRenderModel) -> some View {
    CornerComplicationContentView(model: model)
        .background(.black, in: .rect(cornerRadius: 12))
        .environment(\.colorScheme, .dark)
}

@available(iOS 16.0, watchOS 10.0, *)
#Preview("Icon + name + value + gauge") {
    face(.sample()).padding()
}

@available(iOS 16.0, watchOS 10.0, *)
#Preview("Value + name + gauge") {
    face(.sample(icon: false)).padding()
}

@available(iOS 16.0, watchOS 10.0, *)
#Preview("Value only") {
    face(.sample(icon: false, title: nil, fraction: nil)).padding()
}

@available(iOS 16.0, watchOS 10.0, *)
#Preview("Icon + gauge") {
    face(.sample(showValue: false, title: nil)).padding()
}

/// The long-standing rain-sparkline recipe: an icon plus a block-element bar graph.
@available(iOS 16.0, watchOS 10.0, *)
#Preview("Icon + block-element sparkline") {
    face(.sample(value: "▁▂▃▄▅▆▇█", title: nil, fraction: nil)).padding()
}

/// A legacy Graphic Corner "Gauge Text" complication: its outer text flat and large in the corner tip.
@available(iOS 16.0, watchOS 10.0, *)
#Preview("Legacy flat outer text + gauge") {
    face(.sample(icon: false, value: "16.6", title: nil, curvesText: false)).padding()
}
#endif
