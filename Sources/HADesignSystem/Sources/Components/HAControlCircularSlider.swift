#if !os(watchOS)
import SwiftUI

/// The thermostat dial: a three-quarter ring carrying either one target or a low/high pair, with the
/// room's actual reading marked on the track. The SwiftUI counterpart of the frontend's
/// `ha-control-circular-slider`.
///
/// The angle maths lives in ``HACircularSliderScale`` so it can be tested apart from the drawing.
public struct HAControlCircularSlider: View {
    private let scale: HACircularSliderScale
    private let current: Double?
    private let isDisabled: Bool
    private let diameter: CGFloat
    private let trackColor: Color
    private let activeColor: Color
    @Binding private var low: Double
    @Binding private var high: Double
    private let isDual: Bool

    /// A dial with a single target.
    ///
    /// - Parameters:
    ///   - current: The reading now, marked on the track. Distinct from the target being set.
    ///   - diameter: Taken explicitly for the same reason ``HAGauge``'s is — a ring has no size of
    ///     its own to grow an aspect ratio from.
    public init(
        value: Binding<Double>,
        scale: HACircularSliderScale = HACircularSliderScale(),
        current: Double? = nil,
        isDisabled: Bool = false,
        diameter: CGFloat = 200,
        trackColor: Color = .haDisabled,
        activeColor: Color = .haPrimary
    ) {
        _low = value
        _high = value
        self.isDual = false
        self.scale = scale
        self.current = current
        self.isDisabled = isDisabled
        self.diameter = diameter
        self.trackColor = trackColor
        self.activeColor = activeColor
    }

    /// A dial with a low and a high target, for a thermostat in heat/cool mode.
    public init(
        low: Binding<Double>,
        high: Binding<Double>,
        scale: HACircularSliderScale = HACircularSliderScale(),
        current: Double? = nil,
        isDisabled: Bool = false,
        diameter: CGFloat = 200,
        trackColor: Color = .haDisabled,
        activeColor: Color = .haPrimary
    ) {
        _low = low
        _high = high
        self.isDual = true
        self.scale = scale
        self.current = current
        self.isDisabled = isDisabled
        self.diameter = diameter
        self.trackColor = trackColor
        self.activeColor = activeColor
    }

    /// A trim starts at three o'clock; rotating by this puts the sweep's start at the lower left,
    /// leaving the 90° gap centred at the bottom.
    private static let startAngle: Double = 135
    private var lineWidth: CGFloat { diameter * 0.12 }

    /// The fraction of a full turn the dial covers.
    private var sweepFraction: Double { HACircularSliderScale.sweepDegrees / 360 }

    public var body: some View {
        ZStack {
            ring(from: 0, to: 1, color: trackColor.opacity(0.2))
            // A single-target dial fills from the start; a dual one fills only between its handles.
            ring(
                from: isDual ? scale.percentage(for: low) : 0,
                to: scale.percentage(for: isDual ? high : low),
                color: activeColor
            )
            if let current {
                marker(at: scale.percentage(for: current))
            }
            // Ring handles at the ends you can drag — checked against the rendered
            // ha-control-circular-slider, which marks each target with one. Without them the dial
            // reads as a gauge rather than as something you can take hold of.
            if isDual {
                handle(at: scale.percentage(for: low))
            }
            handle(at: scale.percentage(for: isDual ? high : low))
        }
        .frame(width: diameter, height: diameter)
        .opacity(isDisabled ? 0.5 : 1)
        .accessibilityElement()
        .accessibilityValue(
            Text(
                isDual ? "\(scale.stepped(low).formatted())–\(scale.stepped(high).formatted())"
                    : scale.stepped(low).formatted()
            )
        )
    }

    private func ring(from: Double, to: Double, color: Color) -> some View {
        Circle()
            .trim(from: from * sweepFraction, to: to * sweepFraction)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .rotationEffect(.degrees(Self.startAngle))
            .padding(lineWidth / 2)
    }

    /// The current reading, drawn as a small grey dot on the track rather than a handle — it reports
    /// rather than sets, and the rendered dial keeps it visually quieter than the targets.
    private func marker(at percentage: Double) -> some View {
        Circle()
            .fill(Color.secondary)
            .frame(width: lineWidth / 3, height: lineWidth / 3)
            .offset(y: -(diameter - lineWidth) / 2)
            .rotationEffect(.degrees(Self.startAngle + 90 + percentage * HACircularSliderScale.sweepDegrees))
    }

    /// A ring in the active colour with the surface showing through, sitting on the arc's end.
    private func handle(at percentage: Double) -> some View {
        Circle()
            .fill(Color.haCardBackground)
            .overlay(Circle().strokeBorder(activeColor, lineWidth: lineWidth / 3))
            .frame(width: lineWidth, height: lineWidth)
            .offset(y: -(diameter - lineWidth) / 2)
            .rotationEffect(.degrees(Self.startAngle + 90 + percentage * HACircularSliderScale.sweepDegrees))
            .opacity(isDisabled ? 0 : 1)
    }
}

#Preview("Single target") {
    VStack(spacing: DesignSystem.Spaces.three) {
        HAControlCircularSlider(
            value: .constant(21),
            scale: HACircularSliderScale(min: 7, max: 35, step: 0.5),
            current: 19
        )
        HAControlCircularSlider(value: .constant(60), isDisabled: true)
    }
    .padding()
}

#Preview("Dual target") {
    HAControlCircularSlider(
        low: .constant(18),
        high: .constant(24),
        scale: HACircularSliderScale(min: 7, max: 35, step: 0.5),
        current: 21
    )
    .padding()
}

extension HAControlCircularSlider: FrontendComponent {
    public static var frontendComponentName: String { "ha-control-circular-slider" }
}

#endif
