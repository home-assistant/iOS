import SwiftUI
import WidgetKit

/// A horizontal progress bar with a circular value "thumb" riding the fill, and the minimum / maximum
/// labels below the bar. Mirrors the iOS builder preview.
@available(watchOS 10.0, *)
struct RectangularProgressView: View {
    static let barHeight: CGFloat = 7
    static let thumbSize: CGFloat = 22

    let fraction: Double
    let minLabel: String?
    let maxLabel: String?
    let valueLabel: String?
    let tint: Color

    /// Black on light tints, white on dark ones.
    private var contrastColor: Color {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(tint).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (0.299 * r + 0.587 * g + 0.114 * b) > 0.6 ? .black : .white
    }

    var body: some View {
        let clamped = min(max(fraction, 0), 1)
        VStack(spacing: 3) {
            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(tint.opacity(0.25)).frame(height: Self.barHeight)
                    Capsule().fill(tint).frame(width: max(Self.barHeight, width * clamped), height: Self.barHeight)
                    if let valueLabel {
                        Text(verbatim: valueLabel)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(contrastColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.4)
                            .padding(1)
                            .frame(width: Self.thumbSize, height: Self.thumbSize)
                            .padding(.horizontal, 4)
                            .background(tint)
                            .clipShape(.capsule)
                            .position(
                                x: min(max(width * clamped, Self.thumbSize / 2), width - Self.thumbSize / 2),
                                y: Self.thumbSize / 2
                            )
                    }
                }
                .frame(height: Self.thumbSize)
            }
            .frame(height: Self.thumbSize)
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

// A widget extension can only host widget previews; the rectangular-family widget renders this progress
// bar, so preview it through the widget.
#if DEBUG
@available(watchOS 10.0, *)
#Preview(as: .accessoryRectangular) {
    WatchWidgets()
} timeline: {
    WatchWidgetEntry(date: .now, family: .accessoryRectangular, complication: .previewSample())
}
#endif
