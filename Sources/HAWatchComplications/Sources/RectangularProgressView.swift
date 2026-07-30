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

    let fraction: Double
    let minLabel: String?
    let maxLabel: String?
    let valueLabel: String?
    let tint: Color

    public init(fraction: Double, minLabel: String?, maxLabel: String?, valueLabel: String?, tint: Color) {
        self.fraction = fraction
        self.minLabel = minLabel
        self.maxLabel = maxLabel
        self.valueLabel = valueLabel
        self.tint = tint
    }

    @Environment(\.widgetRenderingMode) private var renderingMode

    /// Full color: black on light tints, white on dark ones. In accented (tinted) mode the pill fill
    /// is placed in the accent group and the text is left in the default group, so the system renders
    /// them in two distinct tint shades; the explicit color is ignored there.
    private var valueTextColor: Color {
        guard renderingMode == .fullColor else { return .white }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(tint).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (0.299 * r + 0.587 * g + 0.114 * b) > 0.6 ? .black : .white
    }

    public var body: some View {
        let clamped = min(max(fraction, 0), 1)
        VStack(spacing: 3) {
            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(tint.opacity(0.25)).frame(height: Self.barHeight)
                    Capsule().fill(tint).frame(width: max(Self.barHeight, width * clamped), height: Self.barHeight)
                    if let valueLabel {
                        ZStack {
                            Capsule()
                                .fill(tint)
                                .widgetAccentable()
                            Text(verbatim: valueLabel)
                                .font(.body.bold())
                                .foregroundStyle(valueTextColor)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .padding(.vertical, 1)
                                .padding(.horizontal, 4)
                        }
                        .frame(width: Self.thumbWidth, height: Self.thumbHeight)
                        .position(
                            x: min(max(width * clamped, Self.thumbWidth / 2), width - Self.thumbWidth / 2),
                            y: Self.thumbHeight / 2
                        )
                    }
                }
                .frame(height: Self.thumbHeight)
            }
            .frame(height: Self.thumbHeight)
            HStack {
                Text(verbatim: minLabel ?? " ")
                Spacer()
                Text(verbatim: maxLabel ?? " ")
            }
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
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
