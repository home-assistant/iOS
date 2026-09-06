import Foundation

/// Turns the system's recurrence rule into the iCalendar RRULE Home Assistant stores.
///
/// Only frequency, interval and how the rule ends are carried across — the parts Siri produces from
/// a spoken phrase. A rule that also narrows by weekday or month-day keeps its frequency and loses
/// the narrowing, which repeats more often than asked rather than silently dropping the event.
@available(iOS 27.0, *)
extension Calendar.RecurrenceRule {
    var rrule: String? {
        guard let frequency = rruleFrequency else { return nil }
        var parts = ["FREQ=\(frequency)"]
        if interval > 1 { parts.append("INTERVAL=\(interval)") }
        switch end {
        case .never:
            break
        default:
            if let count = end.occurrences {
                parts.append("COUNT=\(count)")
            } else if let date = end.date {
                parts.append("UNTIL=\(Self.untilFormatter.string(from: date))")
            }
        }
        return parts.joined(separator: ";")
    }

    private var rruleFrequency: String? {
        switch frequency {
        case .minutely: "MINUTELY"
        case .hourly: "HOURLY"
        case .daily: "DAILY"
        case .weekly: "WEEKLY"
        case .monthly: "MONTHLY"
        case .yearly: "YEARLY"
        @unknown default: nil
        }
    }

    /// RFC 5545 wants UTC with a trailing `Z` for an absolute end.
    private static let untilFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}
