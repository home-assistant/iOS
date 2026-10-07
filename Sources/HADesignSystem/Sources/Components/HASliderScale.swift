import Foundation

/// Maps between a slider's value and its position along the track.
///
/// Split out of ``HAControlSlider`` because this is the part that can be wrong without looking
/// wrong: a snapshot shows a bar at some length, not whether the value it came from was clamped,
/// snapped and inverted in the right order. The rules are the frontend's `ha-control-slider`.
public struct HASliderScale: Equatable, Sendable {
    public let min: Double
    public let max: Double
    public let step: Double
    /// Runs the track the other way, so the value grows towards the leading edge.
    public let inverted: Bool

    public init(min: Double = 0, max: Double = 100, step: Double = 1, inverted: Bool = false) {
        self.min = min
        self.max = max
        self.step = step
        self.inverted = inverted
    }

    /// Clamps into `min...max`.
    public func bounded(_ value: Double) -> Double {
        Swift.min(Swift.max(value, min), max)
    }

    /// Snaps to the nearest step, then clamps.
    ///
    /// The order matters and is easy to get backwards: snapping a value that already sits at a bound
    /// can push it past one when the step does not divide the range evenly — with `min` 1, `max` 99
    /// and `step` 10, snapping alone yields 0 and 100.
    public func stepped(_ value: Double) -> Double {
        guard step > 0 else { return bounded(value) }
        return bounded((value / step).rounded() * step)
    }

    /// Where `value` sits along the track, `0...1` from the track's start.
    public func percentage(for value: Double) -> Double {
        guard max > min else { return 0 }
        let percentage = (bounded(value) - min) / (max - min)
        return inverted ? 1 - percentage : percentage
    }

    /// The value at a point `0...1` along the track. Not snapped — callers decide whether a drag
    /// reports continuously or in steps.
    public func value(atPercentage percentage: Double) -> Double {
        (max - min) * (inverted ? 1 - percentage : percentage) + min
    }

    /// How far an arrow key or a page gesture moves the value: a tenth of the range, or one step if
    /// that is coarser.
    public var largeStep: Double {
        Swift.max(step, (max - min) / 10)
    }
}

extension HASliderScale: FrontendComponent {
    public static var frontendComponentName: String { "ha-control-slider" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}
