import SwiftUI
import WidgetKit

/// A horizontal progress bar with a circular value "thumb" riding the fill, and the minimum / maximum
/// labels below the bar. Mirrors the iOS builder preview.
@available(watchOS 10.0, *)
struct RectangularProgressView: View {
    static let barHeight: CGFloat = 7
    static let thumbHeight: CGFloat = 22
    static let thumbWidth: CGFloat = 34

    let fraction: Double
    let minLabel: String?
    let maxLabel: String?
    let valueLabel: String?
    let tint: Color

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

    var body: some View {
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
