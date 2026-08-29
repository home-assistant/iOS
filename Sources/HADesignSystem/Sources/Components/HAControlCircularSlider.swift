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
    /// Names the dial for VoiceOver. Without it the value is announced with no indication of what
    /// it sets — "21" could be the temperature or the humidity.
    private let label: String?
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
        activeColor: Color = .haPrimary,
        label: String? = nil
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
        self.label = label
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
        activeColor: Color = .haPrimary,
        label: String? = nil
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
        self.label = label
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
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { drag in
                    guard !isDisabled else { return }
                    setTarget(towards: drag.location)
                }
        )
        .accessibilityElement()
        .accessibilityLabel(optional: label)
        .accessibilityValue(
            Text(
                isDual ? "\(scale.stepped(low).formatted())–\(scale.stepped(high).formatted())"
                    : scale.stepped(low).formatted()
            )
        )
        // Without this the dial is announced as a value VoiceOver cannot change — which, for the
        // thermostat and humidifier cards, means the target can be heard but never set.
        .accessibilityAdjustableAction { direction in
            guard !isDisabled else { return }
            let delta = direction == .increment ? scale.step : -scale.step
            if isDual {
                high = scale.boundedHigh(high + delta, low: low)
            } else {
                low = scale.stepped(scale.boundedLow(low + delta, high: nil))
                high = low
            }
        }
    }

    /// Turns a touch into a target: the angle from the dial's centre becomes a percentage along the
    /// sweep, which the scale turns back into a value.
    ///
    /// In dual mode the handle that moves is whichever is already nearer, so dragging near the low
    /// end never drags the high one across it.
    private func setTarget(towards location: CGPoint) {
        let centre = CGPoint(x: diameter / 2, y: diameter / 2)
        let radians = atan2(location.y - centre.y, location.x - centre.x)
        var degrees = radians * 180 / .pi - Self.startAngle
        while degrees < 0 {
            degrees += 360
        }
        // Past the end of the sweep is the 90° gap at the bottom; a touch there is not on the
        // track at all, so snap it to whichever end it is closest to rather than wrapping around.
        guard degrees <= HACircularSliderScale.sweepDegrees + 45 else {
            return
        }
        let percentage = Swift.min(degrees / HACircularSliderScale.sweepDegrees, 1)
        let value = scale.value(atPercentage: percentage)

        guard isDual else {
            low = scale.stepped(value)
            high = low
            return
        }
        if abs(value - low) <= abs(value - high) {
            low = scale.boundedLow(value, high: high)
        } else {
            high = scale.boundedHigh(value, low: low)
        }
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
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
