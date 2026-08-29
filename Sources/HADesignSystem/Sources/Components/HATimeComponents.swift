import Foundation

/// The five editable segments behind ``HABaseTimeInput`` — the SwiftUI counterpart of the
/// `TimeChangedEvent` payload the frontend's `ha-base-time-input` emits.
///
/// The segments are stored as magnitudes; ``HADurationInput`` carries the sign separately, the way
/// `ha-duration-input`'s `allowNegative` toggle does.
public struct HATimeComponents: Equatable, Sendable {
    public var days: Int
    public var hours: Int
    public var minutes: Int
    public var seconds: Int
    public var milliseconds: Int
    public var period: HADayPeriod

    public init(
        days: Int = 0,
        hours: Int = 0,
        minutes: Int = 0,
        seconds: Int = 0,
        milliseconds: Int = 0,
        period: HADayPeriod = .am
    ) {
        self.days = days
        self.hours = hours
        self.minutes = minutes
        self.seconds = seconds
        self.milliseconds = milliseconds
        self.period = period
    }
}

public extension HATimeComponents {
    /// Carries overflow from each segment into the next, as `ha-duration-input`'s `_durationChanged`
    /// does after every edit: typing 90 into the minutes box becomes 1 hour 30 minutes.
    ///
    /// The carries are deliberately not uniform, because the frontend's aren't:
    ///
    /// - Milliseconds carry whenever they exceed 999. This one is unconditional — the frontend
    ///   guards the branch on the millisecond box being hidden *and* the value being zero, so a
    ///   hidden box still carries a non-zero value.
    /// - Seconds carry only when the second box is shown. With it hidden, 90 seconds stays 90.
    /// - Minutes carry unconditionally.
    /// - Hours carry only when the day box is shown, and only past **24**, not at 24 — so a flat
    ///   24 hours stays "24h" rather than becoming "1d", while 25 becomes "1d 1h".
    ///
    /// - Parameter negative: Applies `ha-duration-input`'s minus sign, which negates every non-zero
    ///   segment and leaves the zeroes alone.
    func normalized(
        enableDay: Bool = false,
        enableSecond: Bool = false,
        negative: Bool = false
    ) -> HATimeComponents {
        var result = self
        result.days = abs(result.days)
        result.hours = abs(result.hours)
        result.minutes = abs(result.minutes)
        result.seconds = abs(result.seconds)
        result.milliseconds = abs(result.milliseconds)

        if result.milliseconds > 999 {
            result.seconds += result.milliseconds / 1000
            result.milliseconds %= 1000
        }
        if enableSecond, result.seconds > 59 {
            result.minutes += result.seconds / 60
            result.seconds %= 60
        }
        if result.minutes > 59 {
            result.hours += result.minutes / 60
            result.minutes %= 60
        }
        if enableDay, result.hours > 24 {
            result.days += result.hours / 24
            result.hours %= 24
        }

        if negative {
            result.days = -result.days
            result.hours = -result.hours
            result.minutes = -result.minutes
            result.seconds = -result.seconds
            result.milliseconds = -result.milliseconds
        }
        return result
    }
}

extension HATimeComponents: FrontendComponent {
    public static var frontendComponentName: String { "ha-base-time-input" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}
