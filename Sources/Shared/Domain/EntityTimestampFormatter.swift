import Foundation

/// Formats the ISO 8601 states Home Assistant reports for datetime-backed entities: `device_class:
/// timestamp` / `device_class: date` sensors, and the last-triggered state of buttons and scenes.
///
/// Timestamp states are an absolute instant carrying whatever offset the server sent — usually UTC
/// (`2026-08-03T18:15:00+00:00`), but any valid offset parses. Rendering one verbatim both leaks a
/// machine format into the UI and reads as the wrong timezone, so they're formatted the way the
/// frontend's automatic format does: a localized relative description resolved against the device's
/// own timezone, the same "In 56 minutes" a tile card shows.
///
/// `date` states are different — a bare calendar day with no time or zone — so they're kept in UTC
/// end to end and rendered as a localized date, preserving the day the server meant.
public enum EntityTimestampFormatter {
    /// Home Assistant sends fractional seconds for `last_triggered`-style states but plain seconds
    /// for plenty of `timestamp` sensors, and `ISO8601DateFormatter` rejects whichever of the two it
    /// wasn't configured for — so both spellings get their own formatter.
    private static let fractionalSecondsFormatter = with(ISO8601DateFormatter()) {
        $0.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }

    private static let wholeSecondsFormatter = with(ISO8601DateFormatter()) {
        $0.formatOptions = [.withInternetDateTime]
    }

    /// `device_class: date` states carry no time or zone (`2026-08-03`), so they're parsed — and
    /// below, formatted — in UTC to keep the calendar day the server meant. UTC is already
    /// `ISO8601DateFormatter`'s default, but the day-preservation guarantee shouldn't rest on it.
    private static let dateOnlyFormatter = with(ISO8601DateFormatter()) {
        $0.formatOptions = [.withFullDate]
        $0.timeZone = TimeZone(secondsFromGMT: 0)
    }

    /// Parses a timestamp state, with or without fractional seconds. Nil for the states that aren't
    /// timestamps at all (`unavailable`, `unknown`, or an entity that simply isn't datetime-backed).
    public static func date(from state: String) -> Date? {
        fractionalSecondsFormatter.date(from: state) ?? wholeSecondsFormatter.date(from: state)
    }

    /// A localized relative description of a timestamp state — "In 56 minutes", "2 hours ago" — in
    /// the device's timezone. Nil when the state isn't a parsable timestamp, so callers can fall
    /// back to their usual rendering.
    public static func relativeDescription(for state: String) -> String? {
        guard let timestamp = date(from: state) else { return nil }
        // Built per call rather than cached: the formatter snapshots the current locale, and the
        // watch app outlives a region change.
        let formatter = RelativeDateTimeFormatter()
        return formatter.localizedString(for: timestamp, relativeTo: Current.date())
    }

    /// A localized absolute description of a `device_class: date` state — "Aug 3, 2026". Nil when
    /// the state isn't a parsable date.
    public static func dateDescription(for state: String) -> String? {
        guard let day = dateOnlyFormatter.date(from: state) else { return nil }
        let formatter = with(DateFormatter()) {
            $0.dateStyle = .medium
            $0.timeStyle = .none
            $0.timeZone = TimeZone(secondsFromGMT: 0)
        }
        return formatter.string(from: day)
    }
}
