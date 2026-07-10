import SwiftUI

enum RectangularGaugeMetrics {
    static let barHeight: CGFloat = 7
    static let thumbSize: CGFloat = 22
}

/// A horizontal progress bar with a circular value "thumb" riding the fill, and the minimum / maximum
/// labels below the bar. iPhone-preview counterpart of the on-watch `RectangularProgressView`.
struct RectangularGauge: View {
    let fraction: Double
    let minLabel: String?
    let maxLabel: String?
    let valueLabel: String?
    let tint: Color

    var body: some View {
        let clamped = min(max(fraction, 0), 1)
        VStack(spacing: 3) {
            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(tint.opacity(0.25)).frame(height: RectangularGaugeMetrics.barHeight)
                    Capsule().fill(tint)
                        .frame(
                            width: max(RectangularGaugeMetrics.barHeight, width * clamped),
                            height: RectangularGaugeMetrics.barHeight
                        )
                    if let valueLabel {
                        RectangularGaugeThumb(value: valueLabel, tint: tint)
                            .position(
                                x: min(
                                    max(width * clamped, RectangularGaugeMetrics.thumbSize / 2),
                                    width - RectangularGaugeMetrics.thumbSize / 2
                                ),
                                y: RectangularGaugeMetrics.thumbSize / 2
                            )
                    }
                }
                .frame(height: RectangularGaugeMetrics.thumbSize)
            }
            .frame(height: RectangularGaugeMetrics.thumbSize)
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

/// Circular value marker for the rectangular progress bar: a filled disc in the bar's color with the
/// value inside, in a contrast-aware color.
struct RectangularGaugeThumb: View {
    let value: String
    let tint: Color

    /// Black on light tints, white on dark ones.
    private var contrastColor: Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(tint).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (0.299 * r + 0.587 * g + 0.114 * b) > 0.6 ? .black : .white
    }

    var body: some View {
        Text(verbatim: value)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(contrastColor)
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .padding(1)
            .frame(minWidth: RectangularGaugeMetrics.thumbSize, minHeight: RectangularGaugeMetrics.thumbSize)
            .padding(.horizontal, 4)
            .background(tint)
            .clipShape(.capsule)
    }
}
