#if !os(watchOS)
import SwiftUI

/// A half-circle dial reading a value between a minimum and a maximum. The SwiftUI counterpart of
/// the frontend's `ha-gauge`.
///
/// Two ways to read it, as in the frontend: by default the arc fills up to the value; with `levels`
/// the arc is banded by colour and a needle points at the value instead. This is a different shape
/// from `WidgetGaugeArcView`, which sweeps 270° for the Home Screen — they are not interchangeable.
public struct HAGauge: View {
    private let value: Double
    private let min: Double
    private let max: Double
    private let label: String?
    private let valueText: String?
    private let levels: [HAGaugeLevel]
    private let diameter: CGFloat

    /// - Parameters:
    ///   - valueText: Overrides the formatted number under the dial, for a value that reads better
    ///     as words — the frontend's `valueText`.
    ///   - levels: Colour bands. Passing any switches the gauge to its needle form.
    ///   - diameter: How wide the dial is; it is half as tall. Taken explicitly rather than grown
    ///     from the offered width, because the arcs are shapes with no size of their own — asking
    ///     for an aspect ratio around them collapses to nothing under an unbounded proposal.
    public init(
        value: Double,
        min: Double = 0,
        max: Double = 100,
        label: String? = nil,
        valueText: String? = nil,
        levels: [HAGaugeLevel] = [],
        diameter: CGFloat = 180
    ) {
        self.value = value
        self.min = min
        self.max = max
        self.label = label
        self.valueText = valueText
        self.levels = levels
        self.diameter = diameter
    }

    /// Where a value sits on the dial, `0...1` across the half circle. Out-of-range values are
    /// pinned to the ends rather than sweeping past them.
    private func fraction(for value: Double) -> Double {
        guard max > min else { return 0 }
        return Swift.min(Swift.max((value - min) / (max - min), 0), 1)
    }

    private var sortedLevels: [HAGaugeLevel] {
        levels.sorted { $0.level < $1.level }
    }

    public var body: some View {
        VStack(spacing: DesignSystem.Spaces.one) {
            // The reading sits *inside* the arc, low and centred, with only the label below the
            // dial — checked against the rendered `ha-gauge`, which puts the number in the well of
            // the semicircle rather than under it.
            ZStack(alignment: .bottom) {
                dial
                Text(valueText ?? value.formatted())
                    .font(.system(size: diameter * 0.2))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, lineWidth)
            }
            .frame(width: diameter, height: diameter / 2)
            if let label {
                Text(label)
                    .font(DesignSystem.Font.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var lineWidth: CGFloat { diameter * 0.15 }

    /// The top half of a circle drawn at the full diameter: the circle hangs below the box, which
    /// clips it, so only the upper semicircle shows.
    private var dial: some View {
        ZStack(alignment: .top) {
            ZStack {
                if sortedLevels.isEmpty {
                    // The unfilled arc is barely there in the rendered gauge — a hint of the track,
                    // not a second ring competing with the reading.
                    arc(from: 0, to: 1, diameter: diameter, color: Color.haDisabled.opacity(0.1))
                    arc(from: 0, to: fraction(for: value), diameter: diameter, color: .haPrimary)
                } else {
                    ForEach(Array(sortedLevels.enumerated()), id: \.element.id) { index, level in
                        let next = index + 1 < sortedLevels.count ? sortedLevels[index + 1].level : max
                        arc(
                            from: fraction(for: level.level),
                            to: fraction(for: next),
                            diameter: diameter,
                            color: level.color
                        )
                    }
                }
            }
            .frame(width: diameter, height: diameter)

            if !sortedLevels.isEmpty {
                needle(diameter: diameter)
            }
        }
        .frame(width: diameter, height: diameter / 2, alignment: .top)
        .clipped()
    }

    private func arc(from: Double, to: Double, diameter: CGFloat, color: Color) -> some View {
        Circle()
            // A trim starts at three o'clock and runs clockwise, so half a turn from there is the
            // *lower* semicircle; the half turn below brings it up top and makes the dial read
            // left to right.
            .trim(from: from / 2, to: to / 2)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
            .rotationEffect(.degrees(180))
            .padding(lineWidth / 2)
    }

    /// A stub sitting on the band it points at, not a hand reaching from the centre: the rendered
    /// `ha-gauge` marks the value with a small teardrop riding the arc, so the middle stays clear
    /// for the reading.
    private func needle(diameter: CGFloat) -> some View {
        Capsule()
            .fill(Color(uiColor: .label))
            .frame(width: diameter * 0.05, height: lineWidth)
            .frame(width: diameter, height: diameter / 2, alignment: .top)
            .offset(y: -(diameter / 2 - lineWidth) / 2 + lineWidth / 2)
            .rotationEffect(
                .degrees(180 * fraction(for: value) - 90),
                anchor: UnitPoint(x: 0.5, y: 1)
            )
    }
}

#Preview("Filled") {
    VStack(spacing: DesignSystem.Spaces.three) {
        HAGauge(value: 64, label: "Humidity")
        HAGauge(value: 0, label: "Empty")
        HAGauge(value: 100, label: "Full")
    }
    .frame(width: 200)
    .padding()
}

#Preview("Needle with levels") {
    HAGauge(
        value: 72,
        label: "CPU",
        levels: [
            .init(level: 0, color: .haSuccessColor),
            .init(level: 50, color: .haWarningColor),
            .init(level: 85, color: .haErrorColor),
        ]
    )
    .frame(width: 200)
    .padding()
}

extension HAGauge: FrontendComponent {
    public static var frontendComponentName: String { "ha-gauge" }
}

#endif
