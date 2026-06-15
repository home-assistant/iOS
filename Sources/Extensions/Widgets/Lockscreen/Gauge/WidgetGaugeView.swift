import Shared
import SwiftUI
import WidgetKit

@available(iOS 17.0, *)
struct WidgetGaugeView: View {
    @Environment(\.widgetFamily) private var family
    var entry: WidgetGaugeEntry

    /// Intrinsic size (points) of the `.accessoryCircularCapacity` gauge. That style is
    /// Lock-Screen-sized and ignores its frame, so on the Home Screen (`.systemSmall`) we
    /// scale it up by `tileSize / this` to fill the tile.
    private static let accessoryCircularIntrinsicSize: CGFloat = 74
    /// Inset around the gauge within the `.systemSmall` tile.
    private static let systemSmallPadding: CGFloat = 16

    var body: some View {
        switch entry.gaugeType {
        case .normal:
            styled(GaugeArcView(
                value: entry.value,
                centerLabel: entry.valueLabel,
                minLabel: entry.min,
                maxLabel: entry.max
            ))
        case .singleLabel:
            styled(GaugeArcView(
                value: entry.value,
                centerLabel: entry.valueLabel,
                topLabel: entry.label
            ))
        case .capacity:
            capacity
        }
    }

    /// Applies the Home Screen treatment to a frame-filling gauge: pad it within the tile and
    /// tint it with the brand color. The Lock Screen is tinted (and made monochrome) by the
    /// system, so it renders the gauge as-is.
    @ViewBuilder private func styled(_ gauge: some View) -> some View {
        switch family {
        case .systemSmall:
            gauge
                .padding(Self.systemSmallPadding)
                .tint(Color.haPrimary)
        default:
            gauge
        }
    }

    /// The capacity gauge already fills `0…value` natively (like Apple's Batteries widget), so
    /// it keeps the system style. The accessory style has a fixed Lock-Screen intrinsic size and
    /// won't grow on its own, so on the Home Screen we scale it up to fill the square tile.
    @ViewBuilder private var capacity: some View {
        let gauge = Gauge(value: entry.value) {
            valueLabel
        } currentValueLabel: {
            valueLabel
        }
        .gaugeStyle(.accessoryCircularCapacity)

        switch family {
        case .systemSmall:
            GeometryReader { proxy in
                gauge
                    .scaleEffect(min(proxy.size.width, proxy.size.height) / Self.accessoryCircularIntrinsicSize)
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .clipped()
            .padding(Self.systemSmallPadding)
            .tint(Color.haPrimary)
        default:
            gauge
        }
    }

    @ViewBuilder private var valueLabel: some View {
        if let valueLabel = entry.valueLabel {
            Text(valueLabel)
        } else {
            Text("00")
                .redacted(reason: .placeholder)
        }
    }
}

/// A circular gauge whose tinted arc fills only `0…value`, leaving the remainder as a dim track —
/// matching Apple's Batteries widget. Works on both the full-color Home Screen and the monochrome
/// Lock Screen (where the system's vibrant rendering preserves the bright-fill / dim-track band).
@available(iOS 17.0, *)
private struct GaugeArcView: View {
    /// Gauge value in `0…1`.
    let value: Double
    /// Centered value label (e.g. "84%").
    var centerLabel: String?
    /// Optional label shown above the value (used by the single-label gauge type).
    var topLabel: String?
    /// Optional labels at the gauge's open ends (used by the normal gauge type).
    var minLabel: String?
    var maxLabel: String?

    /// Fraction of the full circle the gauge sweeps (270°), leaving a gap centered at the bottom.
    private static let sweep: CGFloat = 0.75
    /// Stroke width as a fraction of the view's smaller dimension.
    private static let lineWidthRatio: CGFloat = 0.1
    /// Opacity of the unfilled track.
    private static let trackOpacity: CGFloat = 0.25
    /// How far out (as a fraction of the ring radius) the min/max labels sit — kept inside the
    /// ring so the Lock Screen's circular mask doesn't clip them.
    private static let endLabelRadiusRatio: CGFloat = 0.78
    /// sin(45°) == cos(45°); the arc's open ends are on the bottom diagonals.
    private static let sinCos45: CGFloat = 0.7071

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let lineWidth = size * Self.lineWidthRatio
            ZStack {
                arc(to: 1)
                    .stroke(.tint.opacity(Self.trackOpacity), style: strokeStyle(lineWidth))
                arc(to: clampedValue)
                    .stroke(.tint, style: strokeStyle(lineWidth))

                centerLabels(size: size)
                endLabels(size: size, lineWidth: lineWidth)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private var clampedValue: CGFloat {
        max(0, min(1, CGFloat(value)))
    }

    /// An arc sweeping clockwise from the bottom-left up and over to the bottom-right, gap centered
    /// at the bottom. `fraction` (0…1) scales how far along the 270° sweep it travels.
    private func arc(to fraction: CGFloat) -> some Shape {
        Circle()
            .trim(from: 0, to: Self.sweep * fraction)
            .rotation(.degrees(135))
    }

    private func strokeStyle(_ lineWidth: CGFloat) -> StrokeStyle {
        StrokeStyle(lineWidth: lineWidth, lineCap: .round)
    }

    @ViewBuilder private func centerLabels(size: CGFloat) -> some View {
        VStack(spacing: size * 0.02) {
            if let topLabel {
                Text(topLabel)
                    .font(.system(size: size * 0.13, weight: .semibold))
                    .textCase(.uppercase)
            }
            if let centerLabel {
                Text(centerLabel)
                    .font(.system(size: size * 0.24, weight: .semibold, design: .rounded))
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .foregroundStyle(.primary)
    }

    @ViewBuilder private func endLabels(size: CGFloat, lineWidth: CGFloat) -> some View {
        if minLabel != nil || maxLabel != nil {
            // The arc's open ends sit at ±45° from the bottom. Tuck the min/max labels just inside
            // the ring there (rather than at the tile's bottom corners) so they stay within the
            // Lock Screen's circular safe area instead of being clipped by the system mask.
            let radius = (size - lineWidth) / 2 * Self.endLabelRadiusRatio
            let offset = radius * Self.sinCos45
            ZStack {
                if let minLabel {
                    Text(minLabel).offset(x: -offset, y: offset)
                }
                if let maxLabel {
                    Text(maxLabel).offset(x: offset, y: offset)
                }
            }
            .font(.system(size: size * 0.12))
            .foregroundStyle(.primary)
        }
    }
}
