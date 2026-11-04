#if !os(watchOS)
import SwiftUI

/// The thermostat dial: a three-quarter ring carrying either one target or a low/high pair, with the
/// room's actual reading marked on the track. The SwiftUI counterpart of the frontend's
/// `ha-control-circular-slider`.
///
/// The angle maths lives in ``HACircularSliderScale`` so it can be tested apart from the drawing.
public struct HAControlCircularSlider: View {
    /// Which side of the target the colour fills, the frontend's `ControlCircularSliderMode`.
    public enum Mode: String, CaseIterable, Sendable {
        /// From the minimum up to the target: heating.
        case start
        /// From the target up to the maximum: cooling.
        case end
        /// The whole ring, with no target: a reading with nothing to set.
        case full
    }

    private let scale: HACircularSliderScale
    private let current: Double?
    private let mode: Mode
    private let isDisabled: Bool
    private let isInactive: Bool
    private let isReadOnly: Bool
    private let diameter: CGFloat
    private let trackColor: Color
    private let activeColor: Color
    private let highColor: Color?
    /// Names the dial for VoiceOver. Without it the value is announced with no indication of what
    /// it sets — "21" could be the temperature or the humidity.
    private let label: String?
    /// Which target a dual dial's adjustable action moves. Ignored by a single-target dial.
    @State private var adjustsLowerTarget = false
    @Binding private var low: Double
    @Binding private var high: Double
    private let isDual: Bool

    /// A dial with a single target.
    ///
    /// - Parameters:
    ///   - current: The reading now, marked on the track. Distinct from the target being set.
    ///   - mode: Which side of the target is coloured.
    ///   - isInactive: Hides the colour but keeps the target, for an entity that is off.
    ///   - diameter: Taken explicitly for the same reason ``HAGauge``'s is — a ring has no size of
    ///     its own to grow an aspect ratio from.
    public init(
        value: Binding<Double>,
        scale: HACircularSliderScale = HACircularSliderScale(),
        current: Double? = nil,
        mode: Mode = .start,
        isDisabled: Bool = false,
        isInactive: Bool = false,
        isReadOnly: Bool = false,
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
        self.mode = mode
        self.isDisabled = isDisabled
        self.isInactive = isInactive
        self.isReadOnly = isReadOnly
        self.diameter = diameter
        self.trackColor = trackColor
        self.activeColor = activeColor
        self.highColor = nil
        self.label = label
    }

    /// A dial with a low and a high target, for a thermostat in heat/cool mode. The low target
    /// colours up from the minimum and the high one down from the maximum.
    ///
    /// - Parameter highColor: The high target's colour (cooling, where the low one is heating).
    ///   Defaults to `activeColor`.
    public init(
        low: Binding<Double>,
        high: Binding<Double>,
        scale: HACircularSliderScale = HACircularSliderScale(),
        current: Double? = nil,
        isDisabled: Bool = false,
        isInactive: Bool = false,
        isReadOnly: Bool = false,
        diameter: CGFloat = 200,
        trackColor: Color = .haDisabled,
        activeColor: Color = .haPrimary,
        highColor: Color? = nil,
        label: String? = nil
    ) {
        _low = low
        _high = high
        self.isDual = true
        self.scale = scale
        self.current = current
        self.mode = .start
        self.isDisabled = isDisabled
        self.isInactive = isInactive
        self.isReadOnly = isReadOnly
        self.diameter = diameter
        self.trackColor = trackColor
        self.activeColor = activeColor
        self.highColor = highColor
        self.label = label
    }

    /// A trim starts at three o'clock; rotating by this puts the sweep's start at the lower left,
    /// leaving the 90° gap centred at the bottom.
    private static let startAngle: Double = 135
    /// The frontend draws a 24px stroke on a 320px dial.
    private var lineWidth: CGFloat { diameter * 24 / 320 }
    private var dotSize: CGFloat { lineWidth / 3 }

    /// The fraction of a full turn the dial covers.
    private var sweepFraction: Double { HACircularSliderScale.sweepDegrees / 360 }

    private var acceptsInput: Bool { !isDisabled && !isReadOnly && mode != .full }

    public var body: some View {
        ZStack {
            ring(from: 0, to: 1, color: trackColor.opacity(0.3))
            if let current, !isCurrentOutOfRange(current) {
                dot(at: scale.percentage(for: current), color: Color(uiColor: .label).opacity(0.5))
            }
            if !isDisabled {
                if isDual {
                    arcs(target: low, mode: .start, color: activeColor)
                    arcs(target: high, mode: .end, color: highColor ?? activeColor)
                } else {
                    arcs(target: low, mode: mode, color: activeColor)
                }
            }
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { drag in
                    guard acceptsInput else { return }
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
        .modify { view in
            if acceptsInput {
                view.accessibilityAdjustableAction { direction in
                    adjust(by: direction == .increment ? scale.step : -scale.step)
                }
            }
        }
        // A dual dial has two targets and one adjustable action, so the swipe moves whichever
        // handle these actions have selected. Without them the lower target could be heard but
        // never changed.
        .accessibilityAction(named: Text(HADesignSystemEnvironment.current.strings.adjustLowerTarget)) {
            adjustsLowerTarget = true
        }
        .accessibilityAction(named: Text(HADesignSystemEnvironment.current.strings.adjustUpperTarget)) {
            adjustsLowerTarget = false
        }
    }

    private func isCurrentOutOfRange(_ current: Double) -> Bool {
        current < scale.min || current > scale.max
    }

    /// One target's arcs, as `renderArc` draws them: the side it colours at half strength, the
    /// stretch between the reading and the target at full strength when the target is ahead of the
    /// reading, the reading's mark on that stretch, and the handle.
    @ViewBuilder
    private func arcs(target: Double, mode: Mode, color: Color) -> some View {
        let limit = mode == .end ? scale.max : scale.min
        let reading = current ?? limit
        let showsActive = switch mode {
        case .start: reading <= target
        case .end: target <= reading
        case .full: false
        }
        let targetPercentage = scale.percentage(for: target)
        let readingPercentage = scale.percentage(for: reading)
        let colored: (Double, Double) = switch mode {
        case .full: (0, 1)
        case .end: (targetPercentage, 1)
        case .start: (0, targetPercentage)
        }

        Group {
            ring(from: colored.0, to: colored.1, color: .haCardBackground)
            ring(from: colored.0, to: colored.1, color: color.opacity(0.5))
            if mode != .full {
                if showsActive {
                    ring(
                        from: Swift.min(readingPercentage, targetPercentage),
                        to: Swift.max(readingPercentage, targetPercentage),
                        color: color
                    )
                } else {
                    dot(at: targetPercentage, color: color, size: lineWidth)
                }
            }
            if let current, !isCurrentOutOfRange(current), showsActive || mode == .full {
                dot(at: scale.percentage(for: current), color: .haCardBackground)
            }
        }
        .opacity(isInactive ? 0 : 1)

        if mode != .full {
            handle(at: targetPercentage, color: color)
        }
    }

    private func adjust(by delta: Double) {
        guard isDual else {
            low = scale.stepped(scale.boundedLow(low + delta, high: nil))
            high = low
            return
        }
        if adjustsLowerTarget {
            low = scale.boundedLow(scale.stepped(low + delta), high: high)
        } else {
            high = scale.boundedHigh(scale.stepped(high + delta), low: low)
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
        // Snapped before bounding, the order the scale documents: bounding a raw value would let a
        // dial with a half-degree step write arbitrary fractions of one.
        let snapped = scale.stepped(value)
        if abs(value - low) <= abs(value - high) {
            low = scale.boundedLow(snapped, high: high)
        } else {
            high = scale.boundedHigh(snapped, low: low)
        }
    }

    private func ring(from: Double, to: Double, color: Color) -> some View {
        Circle()
            .trim(from: from * sweepFraction, to: to * sweepFraction)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .rotationEffect(.degrees(Self.startAngle))
            .padding(lineWidth / 2)
    }

    private func dot(at percentage: Double, color: Color, size: CGFloat? = nil) -> some View {
        Circle()
            .fill(color)
            .frame(width: size ?? dotSize, height: size ?? dotSize)
            .offset(y: -(diameter - lineWidth) / 2)
            .rotationEffect(.degrees(Self.startAngle + 90 + percentage * HACircularSliderScale.sweepDegrees))
    }

    /// The target: a white disc ringed in the target's colour, sitting on the arc: the frontend's
    /// `target-border` under `target`.
    private func handle(at percentage: Double, color: Color) -> some View {
        Circle()
            .fill(.white)
            .overlay(Circle().strokeBorder(color, lineWidth: lineWidth / 8))
            .frame(width: lineWidth, height: lineWidth)
            .offset(y: -(diameter - lineWidth) / 2)
            .rotationEffect(.degrees(Self.startAngle + 90 + percentage * HACircularSliderScale.sweepDegrees))
    }
}

#Preview("Single target") {
    VStack(spacing: DesignSystem.Spaces.three) {
        HAControlCircularSlider(
            value: .constant(21),
            scale: HACircularSliderScale(min: 7, max: 35, step: 0.5),
            current: 19
        )
        HAControlCircularSlider(
            value: .constant(18),
            scale: HACircularSliderScale(min: 7, max: 35, step: 0.5),
            current: 24,
            mode: .end
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
        current: 21,
        activeColor: .orange,
        highColor: .blue
    )
    .padding()
}

extension HAControlCircularSlider: FrontendComponent {
    public static var frontendComponentName: String { "ha-control-circular-slider" }
    public static var frontendComponentVersion: String { "2026-10-12" }
}

#endif
