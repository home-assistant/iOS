import Foundation

/// Maps between a circular slider's value and its angle around the dial.
///
/// Split out of ``HAControlCircularSlider`` for the same reason ``HASliderScale`` is: an arc of some
/// length looks right whether or not the value behind it was bounded correctly, and in dual mode the
/// bounds depend on the *other* handle.
///
/// Note this snaps without clamping, unlike the linear slider — the frontend keeps the two apart
/// because a dual dial clamps against its sibling handle rather than against the range.
///
/// Frontend counterpart: the value maths inside `ha-control-circular-slider`, which keeps it in the
/// element rather than apart from it.
public struct HACircularSliderScale: Equatable, Sendable {
    /// The dial is three quarters of a turn, with the gap centred at the bottom.
    public static let sweepDegrees: Double = 270

    public let min: Double
    public let max: Double
    public let step: Double

    public init(min: Double = 0, max: Double = 100, step: Double = 1) {
        self.min = min
        self.max = max
        self.step = step
    }

    /// Where `value` sits around the dial, `0...1` from the sweep's start.
    public func percentage(for value: Double) -> Double {
        guard max > min else { return 0 }
        return (Swift.min(Swift.max(value, min), max) - min) / (max - min)
    }

    public func value(atPercentage percentage: Double) -> Double {
        (max - min) * percentage + min
    }

    /// Snaps to the nearest step. Deliberately not clamped: which bounds apply depends on whether
    /// this is the low handle, the high handle or a lone one.
    public func stepped(_ value: Double) -> Double {
        guard step > 0 else { return value }
        return (value / step).rounded() * step
    }

    /// Degrees around the dial from its start, `0...270`.
    public func angle(for value: Double) -> Double {
        percentage(for: value) * Self.sweepDegrees
    }

    /// The low handle cannot pass the high one, and stops at the range's floor.
    public func boundedLow(_ value: Double, high: Double?) -> Double {
        Swift.min(Swift.max(value, min), high ?? max)
    }

    /// The high handle cannot fall below the low one, and stops at the range's ceiling.
    public func boundedHigh(_ value: Double, low: Double?) -> Double {
        Swift.max(Swift.min(value, max), low ?? min)
    }
}

extension HACircularSliderScale: FrontendComponent {
    public static var frontendComponentName: String { "ha-control-circular-slider" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}
