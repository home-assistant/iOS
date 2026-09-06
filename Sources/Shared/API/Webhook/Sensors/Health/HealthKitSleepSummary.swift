#if os(iOS) && !targetEnvironment(macCatalyst)
import Foundation

/// The sleep samples of one night, and the arithmetic that turns them into sensor states.
///
/// A night is the sleep day a sample ends in: sleep days run from `sleepDayStartHour` to the same
/// hour the next day, so a night that straddles midnight stays in one piece and an afternoon nap
/// joins the night before it. Reporting the latest night with samples, rather than the sleep day
/// containing "now", keeps last night visible all day instead of dropping it the moment a new sleep
/// day starts.
public struct HealthKitSleepSummary: Equatable, Sendable {
    /// Local hour at which one sleep day ends and the next begins.
    public static let sleepDayStartHour = 18

    /// Start of the sleep day the night belongs to.
    public let start: Date
    public let samples: [HealthKitSleepSample]

    /// The samples belonging to the most recent sleep day that has any, `nil` when there are none.
    public static func latestNight(in samples: [HealthKitSleepSample], calendar: Calendar) -> HealthKitSleepSummary? {
        guard let latest = samples.max(by: { $0.end < $1.end }) else {
            return nil
        }

        let start = sleepDayStart(containing: latest.end, calendar: calendar)
        let night = samples.filter { sleepDayStart(containing: $0.end, calendar: calendar) == start }
        return HealthKitSleepSummary(start: start, samples: night)
    }

    /// The start of the sleep day containing `date`: the most recent `sleepDayStartHour` at or before it.
    public static func sleepDayStart(containing date: Date, calendar: Calendar) -> Date {
        let sameDay = calendar.date(
            bySettingHour: sleepDayStartHour,
            minute: 0,
            second: 0,
            of: date
        ) ?? date

        if sameDay <= date {
            return sameDay
        }
        return calendar.date(byAdding: .day, value: -1, to: sameDay) ?? sameDay
    }

    /// Minutes spent in any of `stages` during the night.
    ///
    /// Overlapping samples are only counted once, since an iPhone, an Apple Watch and a third-party
    /// app can all record the same night. Returns `nil` when nothing that night was recorded by a
    /// source tracking those stages, which is "not tracked" rather than zero minutes.
    public func minutes(in stages: Set<HealthKitSleepStage>) -> Double? {
        guard records(stages) else {
            return nil
        }

        let intervals = samples
            .filter { stages.contains($0.stage) && $0.end > $0.start }
            .map { DateInterval(start: $0.start, end: $0.end) }

        return Self.mergedDuration(of: intervals) / 60
    }

    private func records(_ stages: Set<HealthKitSleepStage>) -> Bool {
        let related = stages.reduce(into: Set<HealthKitSleepStage>()) { $0.formUnion($1.recordedAlongside) }
        return samples.contains { related.contains($0.stage) }
    }

    /// Total length of the union of `intervals`, in seconds.
    private static func mergedDuration(of intervals: [DateInterval]) -> TimeInterval {
        var total: TimeInterval = 0
        var current: DateInterval?

        for interval in intervals.sorted(by: { $0.start < $1.start }) {
            guard let open = current, open.end >= interval.start else {
                total += current?.duration ?? 0
                current = interval
                continue
            }
            current = DateInterval(start: open.start, end: max(open.end, interval.end))
        }

        return total + (current?.duration ?? 0)
    }
}
#endif
