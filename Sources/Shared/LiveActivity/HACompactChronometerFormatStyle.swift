#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation

/// Formats a Live Activity chronometer into at most two fields: `H:MM` once an hour or more is
/// left (or elapsed), `M:SS` below that. Used where three fields do not fit, such as the Dynamic
/// Island compact trailing slot.
@available(iOS 18.0, *)
public struct HACompactChronometerFormatStyle: DiscreteFormatStyle {
    public enum Direction: Codable, Hashable, Sendable {
        case countingDown
        case countingUp
    }

    /// Countdown target when counting down, elapsed-time origin when counting up.
    public let anchor: Date
    /// Point at which a count-up stops advancing; `nil` counts up indefinitely.
    public let freezesAt: Date?
    public let direction: Direction
    public var locale: Locale

    private static let secondsPerMinute = 60
    private static let secondsPerHour = 3600
    /// A century, keeping arithmetic on nonsense dates from a malformed payload well inside `Int`.
    private static let maximumDisplayedSeconds = 100 * 365 * 24 * 3600

    public init(
        anchor: Date,
        direction: Direction,
        freezesAt: Date? = nil,
        locale: Locale = .autoupdatingCurrent
    ) {
        self.anchor = anchor
        self.direction = direction
        self.freezesAt = freezesAt
        self.locale = locale
    }

    public func format(_ input: Date) -> String {
        let seconds = displayedSeconds(at: input)
        let pattern: Duration.TimeFormatStyle.Pattern = seconds >= Self.secondsPerHour
            ? .hourMinute(padHourToLength: 1, roundSeconds: .down)
            : .minuteSecond(padMinuteToLength: 1, roundFractionalSeconds: .down)
        return Duration.seconds(seconds).formatted(.time(pattern: pattern).locale(locale))
    }

    public func locale(_ locale: Locale) -> Self {
        .init(anchor: anchor, direction: direction, freezesAt: freezesAt, locale: locale)
    }

    public func discreteInput(before input: Date) -> Date? {
        let (step, bucket) = stepAndBucket(at: input)
        switch direction {
        case .countingDown:
            return anchor.addingTimeInterval(-Double((bucket + 1) * step))
        case .countingUp:
            guard bucket > 0 else { return nil }
            return Self.input(before: anchor.addingTimeInterval(Double(bucket * step)))
        }
    }

    public func discreteInput(after input: Date) -> Date? {
        let (step, bucket) = stepAndBucket(at: input)
        switch direction {
        case .countingDown:
            guard bucket > 0 else { return nil }
            return Self.input(after: anchor.addingTimeInterval(-Double(bucket * step)))
        case .countingUp:
            let next = anchor.addingTimeInterval(Double((bucket + 1) * step))
            if let freezesAt, next > freezesAt {
                return nil
            }
            return next
        }
    }

    public func input(before input: Date) -> Date? {
        Self.input(before: input)
    }

    public func input(after input: Date) -> Date? {
        Self.input(after: input)
    }

    private func displayedSeconds(at input: Date) -> Int {
        switch direction {
        case .countingDown:
            return Self.flooredSeconds(anchor.timeIntervalSince(input))
        case .countingUp:
            let elapsed = input.timeIntervalSince(anchor)
            guard let freezesAt else { return Self.flooredSeconds(elapsed) }
            return Self.flooredSeconds(min(elapsed, freezesAt.timeIntervalSince(anchor)))
        }
    }

    private func stepAndBucket(at input: Date) -> (step: Int, bucket: Int) {
        let seconds = displayedSeconds(at: input)
        let step = seconds >= Self.secondsPerHour ? Self.secondsPerMinute : 1
        return (step, seconds / step)
    }

    private static func flooredSeconds(_ interval: TimeInterval) -> Int {
        guard interval > 0 else { return 0 }
        return Int(min(interval.rounded(.down), TimeInterval(maximumDisplayedSeconds)))
    }

    private static func input(before input: Date) -> Date {
        Date(timeIntervalSinceReferenceDate: input.timeIntervalSinceReferenceDate.nextDown)
    }

    private static func input(after input: Date) -> Date {
        Date(timeIntervalSinceReferenceDate: input.timeIntervalSinceReferenceDate.nextUp)
    }
}
#endif
