#if !os(watchOS)
import SwiftUI

/// A circular gauge whose tinted arc fills only `0…value`, leaving the remainder as a dim track —
/// matching Apple's Batteries widget. Used on the full-color Home Screen.
@available(iOS 17.0, *)
public struct WidgetGaugeArcView: View {
    /// Gauge value in `0…1`.
    public let value: Double
    /// Centered value label (e.g. "84%").
    public var centerLabel: String?
    /// Optional label shown above the value (used by the single-label gauge type).
    public var topLabel: String?
    /// Optional labels at the gauge's open ends (used by the normal gauge type).
    public var minLabel: String?
    public var maxLabel: String?
    /// Whether the arc should use the full circle range, used by the capacity gauge type.
    public var usesFullCircleRange = false
    /// The mark the open-bottom gauge tucks under its arc. The design system ships no assets of its
    /// own, so the app hands its logo in.
    public var logo: Image?

    public init(
        value: Double,
        centerLabel: String? = nil,
        topLabel: String? = nil,
        minLabel: String? = nil,
        maxLabel: String? = nil,
        usesFullCircleRange: Bool = false,
        logo: Image? = nil
    ) {
        self.value = value
        self.centerLabel = centerLabel
        self.topLabel = topLabel
        self.minLabel = minLabel
        self.maxLabel = maxLabel
        self.usesFullCircleRange = usesFullCircleRange
        self.logo = logo
    }

    /// Fraction of the full circle the gauge sweeps (270°), leaving a gap centered at the bottom.
    private static let sweep: CGFloat = 0.75
    /// Stroke width as a fraction of the view's smaller dimension.
    private static let lineWidthRatio: CGFloat = 0.1
    /// Opacity of the unfilled track.
    private static let trackOpacity: CGFloat = 0.25
    /// Rotation that places the 270° sweep's gap at the bottom.
    private static let arcRotationDegrees: Double = 135
    /// Minimum and maximum values for the normalized gauge fill.
    private static let minimumValue: CGFloat = 0
    private static let maximumValue: CGFloat = 1
    /// Fixed drawing size. The parent widget scales this view to match the system-small tile.
    private static let gaugeSize: CGFloat = 150
    /// Nudge the whole composition down so the open-bottom 270° arc reads as vertically centered.
    /// The arc is top-weighted — its drawn span reaches the top but stops short of the bottom.
    private static let verticalCenteringOffset: CGFloat = 10
    private static let centerLabelSpacing: CGFloat = 3
    private static let logoSize: CGFloat = 22
    private static let minimumLabelScaleFactor: CGFloat = 0.5
    private static let endLabelsContainerPadding: CGFloat = 28
    private static let labelLineLimit = 1

    public var body: some View {
        ZStack {
            trackArc
                .stroke(.tint.opacity(Self.trackOpacity), style: strokeStyle(Self.lineWidth))
            valueArc
                .stroke(.tint, style: strokeStyle(Self.lineWidth))

            centerLabels
            endLabels
        }
        .frame(width: Self.gaugeSize, height: Self.gaugeSize)
        .overlay(alignment: .bottom) {
            if showsLogoAsBottomOverlay {
                homeAssistantLogo
                    .offset(y: -DesignSystem.Spaces.one)
            }
        }
        .offset(y: verticalCenteringOffset)
    }

    private static var lineWidth: CGFloat {
        gaugeSize * lineWidthRatio
    }

    private var clampedValue: CGFloat {
        max(Self.minimumValue, min(Self.maximumValue, CGFloat(value)))
    }

    private var trackArc: some Shape {
        arc(to: Self.maximumValue)
    }

    private var valueArc: some Shape {
        arc(to: clampedValue)
    }

    /// An arc sweeping clockwise from the bottom-left up and over to the bottom-right, gap centered
    /// at the bottom. `fraction` (0…1) scales how far along the 270° sweep it travels.
    private func arc(to fraction: CGFloat) -> some Shape {
        Circle()
            .trim(from: Self.minimumValue, to: arcRangeEnd(for: fraction))
            .rotation(.degrees(rotationDegrees))
    }

    private func arcRangeEnd(for fraction: CGFloat) -> CGFloat {
        usesFullCircleRange ? fraction : Self.sweep * fraction
    }

    private var rotationDegrees: Double {
        usesFullCircleRange ? -90 : Self.arcRotationDegrees
    }

    private var verticalCenteringOffset: CGFloat {
        usesFullCircleRange ? .zero : Self.verticalCenteringOffset
    }

    private func strokeStyle(_ lineWidth: CGFloat) -> StrokeStyle {
        StrokeStyle(lineWidth: lineWidth, lineCap: .round)
    }

    @ViewBuilder private var centerLabels: some View {
        VStack(spacing: Self.centerLabelSpacing) {
            if showsLogoInLabelStack {
                homeAssistantLogo
            }
            if let topLabel {
                Text(verbatim: topLabel)
                    .font(DesignSystem.Font.title3)
                    .foregroundStyle(.secondary)
            }
            if let centerLabel {
                Text(verbatim: centerLabel)
                    .font(DesignSystem.Font.largeTitle.bold())
                    .foregroundStyle(.primary)
            }
        }
        .lineLimit(Self.labelLineLimit)
        .minimumScaleFactor(Self.minimumLabelScaleFactor)
        .foregroundStyle(.primary)
    }

    private var showsLogoInLabelStack: Bool {
        usesFullCircleRange && topLabel == nil && centerLabel != nil
    }

    private var showsLogoAsBottomOverlay: Bool {
        !usesFullCircleRange
    }

    @ViewBuilder private var homeAssistantLogo: some View {
        if let logo {
            logo
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: Self.logoSize, height: Self.logoSize)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder private var endLabels: some View {
        if minLabel != nil || maxLabel != nil {
            HStack(spacing: .zero) {
                if let minLabel {
                    endLabel(minLabel)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if minLabel != nil, maxLabel != nil {
                    Spacer()
                }
                if let maxLabel {
                    endLabel(maxLabel)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(Self.endLabelsContainerPadding)
            .clipShape(.circle)
            .foregroundStyle(.primary)
        }
    }

    private func endLabel(_ text: String) -> some View {
        Text(verbatim: text)
            .font(DesignSystem.Font.body)
            .foregroundStyle(.secondary)
    }
}

@available(iOS 17.0, *)
#Preview {
    WidgetGaugeArcView(value: 0.67, centerLabel: "67%", minLabel: "0", maxLabel: "100")
        .tint(Color.haPrimary)
        .frame(width: 160, height: 160)
}
#endif
