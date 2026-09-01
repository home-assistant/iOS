import SwiftUI
import UIKit
import WidgetKit

/// A horizontal progress bar with a value "thumb" riding the fill, and the minimum / maximum labels
/// below the bar. Shared by the watch rectangular complication and the in-app editor preview.
@available(iOS 16.0, watchOS 10.0, *)
public struct RectangularProgressView: View {
    public static let barHeight: CGFloat = 7
    public static let thumbHeight: CGFloat = 22
    public static let thumbWidth: CGFloat = 34

    /// Layout and styling metrics for the progress bar.
    private enum Layout {
        /// Vertical gap between the bar and the min/max labels.
        static let stackSpacing: CGFloat = 3
        /// Opacity of the unfilled bar track.
        static let trackOpacity: CGFloat = 0.25
        static let thumbVerticalPadding: CGFloat = 1
        static let thumbHorizontalPadding: CGFloat = 6
        static let minMaxLabelFontSize: CGFloat = 10
    }

    /// Actual thumb width, measured so the pill can grow to fit longer values (e.g. "22.7°") while a
    /// minimum keeps it pill-shaped for short ones. Used to keep the thumb clamped inside the bar.
    @State private var thumbWidth: CGFloat = RectangularProgressView.thumbWidth

    /// Weights and threshold for the perceived-luminance check that picks black vs. white value text.
    private enum Luminance {
        static let red: CGFloat = 0.299
        static let green: CGFloat = 0.587
        static let blue: CGFloat = 0.114
        /// Luminance above this is considered "light", so value text switches to black.
        static let lightThreshold: CGFloat = 0.6
    }

    let fraction: Double
    let minLabel: String?
    let maxLabel: String?
    let valueLabel: String?
    let tint: Color
    /// The complication's configured text color, or nil to pick automatically for contrast against
    /// the pill. The value rides the bar rather than sitting in the text stack, so it is the one text
    /// slot that would otherwise ignore the color the user set for it.
    let valueColor: Color?

    public init(
        fraction: Double,
        minLabel: String?,
        maxLabel: String?,
        valueLabel: String?,
        tint: Color,
        valueColor: Color? = nil
    ) {
        self.fraction = fraction
        self.minLabel = minLabel
        self.maxLabel = maxLabel
        self.valueLabel = valueLabel
        self.tint = tint
        self.valueColor = valueColor
    }

    @Environment(\.widgetRenderingMode) private var renderingMode

    /// Full color: the complication's own text color when it has one, else black on light tints and
    /// white on dark ones. In accented (tinted) mode the pill fill is placed in the accent group and
    /// the text is left in the default group, so the system renders them in two distinct tint shades;
    /// the explicit color is ignored there.
    private var valueTextColor: Color {
        guard renderingMode == .fullColor else { return .white }
        return Self.valueLabelColor(configured: valueColor, tint: tint)
    }

    /// The pill label's color in full color: the configured text color wins, otherwise the shade that
    /// reads best on the tint. Pure and static so the choice is testable without rendering a face.
    public static func valueLabelColor(configured: Color?, tint: Color) -> Color {
        if let configured { return configured }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(tint).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Luminance.red * r + Luminance.green * g + Luminance.blue * b) > Luminance.lightThreshold
            ? .black : .white
    }

    /// The value pill riding the bar. Full color and accented both draw the text over the fill, which
    /// the system colours as two separate groups. Vibrant (watch night mode, iPhone Lock Screen)
    /// desaturates everything into a single shade, so the value is rendered by punching the glyphs out
    /// of the pill and revealing the pill’s backing capsule instead of drawing tinted text over the fill.
    @ViewBuilder
    private func thumb(_ valueLabel: String) -> some View {
        let label = Text(verbatim: valueLabel)
            .font(.body.bold())
            .lineLimit(1)
            .padding(.vertical, Layout.thumbVerticalPadding)
            .padding(.horizontal, Layout.thumbHorizontalPadding)

        if renderingMode == .vibrant {
            ZStack {
                // Backs the pill so the bar passing behind it can't show through the knocked-out glyphs.
                Capsule().fill(.black)
                ZStack {
                    Capsule().fill(tint)
                    label
                        .foregroundStyle(.white)
                        .blendMode(.destinationOut)
                }
                .compositingGroup()
            }
        } else {
            ZStack {
                Capsule()
                    .fill(tint)
                    .widgetAccentable()
                label.foregroundStyle(valueTextColor)
            }
        }
    }

    public var body: some View {
        let clamped = min(max(fraction, 0), 1)
        VStack(spacing: Layout.stackSpacing) {
            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(tint.opacity(Layout.trackOpacity)).frame(height: Self.barHeight)
                    Capsule().fill(tint).frame(width: max(Self.barHeight, width * clamped), height: Self.barHeight)
                    if let valueLabel {
                        thumb(valueLabel)
                            // Fit the value: grow past the minimum pill width so it never crops, keeping a
                            // fixed height. `fixedSize` sizes to the text on every platform (no async
                            // measurement), and the measured width keeps the thumb clamped inside the bar.
                            .frame(height: Self.thumbHeight)
                            .frame(minWidth: Self.thumbWidth)
                            .fixedSize(horizontal: true, vertical: false)
                            .background(
                                GeometryReader { proxy in
                                    Color.clear
                                        .onAppear { thumbWidth = proxy.size.width }
                                        .onChange(of: proxy.size.width) { thumbWidth = $0 }
                                }
                            )
                            .position(
                                x: min(max(width * clamped, thumbWidth / 2), width - thumbWidth / 2),
                                y: Self.thumbHeight / 2
                            )
                    }
                }
                .frame(height: Self.thumbHeight)
            }
            .frame(height: Self.thumbHeight)
            if minLabel != nil || maxLabel != nil {
                HStack {
                    Text(verbatim: minLabel ?? " ")
                    Spacer()
                    Text(verbatim: maxLabel ?? " ")
                }
                .font(.system(size: Layout.minMaxLabelFontSize))
                .foregroundStyle(.secondary)
            }
        }
    }
}

#if DEBUG
@available(iOS 16.0, watchOS 10.0, *)
#Preview("Gauge") {
    RectangularProgressView(fraction: 0.68, minLabel: "0", maxLabel: "100", valueLabel: "68", tint: .green)
        .frame(width: 180)
        .padding()
}

// The complication's own text color applies to the value riding the bar, not just the text stack.
@available(iOS 16.0, watchOS 10.0, *)
#Preview("Custom value color") {
    RectangularProgressView(
        fraction: 0.68,
        minLabel: "0",
        maxLabel: "100",
        valueLabel: "68",
        tint: .green,
        valueColor: .yellow
    )
    .frame(width: 180)
    .padding()
}

// Fraction edge cases: the thumb stays inside the bar at the extremes, and out-of-range values clamp.
@available(iOS 16.0, watchOS 10.0, *)
#Preview("Fractions") {
    VStack(spacing: 20) {
        RectangularProgressView(fraction: 0, minLabel: "0", maxLabel: "100", valueLabel: "0", tint: .blue)
        RectangularProgressView(fraction: 0.5, minLabel: "0", maxLabel: "100", valueLabel: "50", tint: .blue)
        RectangularProgressView(fraction: 1, minLabel: "0", maxLabel: "100", valueLabel: "100", tint: .blue)
        RectangularProgressView(fraction: 1.4, minLabel: "0", maxLabel: "100", valueLabel: "140", tint: .red)
        RectangularProgressView(fraction: -0.3, minLabel: "0", maxLabel: "100", valueLabel: "-30", tint: .red)
    }
    .frame(width: 180)
    .padding()
}

// Optional labels: min, max, and value are each independently omittable.
@available(iOS 16.0, watchOS 10.0, *)
#Preview("Optional labels") {
    VStack(spacing: 20) {
        RectangularProgressView(fraction: 0.6, minLabel: nil, maxLabel: nil, valueLabel: "60", tint: .purple)
        RectangularProgressView(fraction: 0.6, minLabel: "0", maxLabel: "100", valueLabel: nil, tint: .purple)
        RectangularProgressView(fraction: 0.6, minLabel: "Low", maxLabel: nil, valueLabel: "60", tint: .purple)
    }
    .frame(width: 180)
    .padding()
}

// Long values/labels: the thumb scales its text down and long min/max labels stay readable.
@available(iOS 16.0, watchOS 10.0, *)
#Preview("Long values") {
    VStack(spacing: 20) {
        RectangularProgressView(fraction: 0.42, minLabel: "0 kWh", maxLabel: "1000 kWh", valueLabel: "420", tint: .teal)
        RectangularProgressView(fraction: 0.9, minLabel: "min", maxLabel: "max", valueLabel: "1234", tint: .teal)
    }
    .frame(width: 180)
    .padding()
}
#endif
