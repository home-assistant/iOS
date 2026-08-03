import Foundation

/// Formats the ISO 8601 states Home Assistant reports for datetime-backed entities: `device_class:
/// timestamp` / `device_class: date` sensors, and the last-triggered state of buttons and scenes.
///
/// The server sends those states as machine-readable UTC (`2026-08-03T18:15:00+00:00`), so rendering
/// them verbatim both leaks an unreadable format into the UI and reads as the wrong timezone. This
/// mirrors the frontend's automatic time format instead — a localized relative description in the
/// device's own timezone, the same "In 56 minutes" a tile card shows.
public enum EntityTimestampFormatter {
    /// Home Assistant sends fractional seconds for `last_triggered`-style states but plain seconds
    /// for plenty of `timestamp` sensors, and `ISO8601DateFormatter` rejects whichever of the two it
    /// wasn't configured for — so both spellings get their own formatter.
    private static let timestampFormatters: [ISO8601DateFormatter] = {
        let optionSets: [ISO8601DateFormatter.Options] = [
            [.withInternetDateTime, .withFractionalSeconds],
            [.withInternetDateTime],
        ]
        return optionSets.map { options in
            with(ISO8601DateFormatter()) { $0.formatOptions = options }
        }
    }()

    /// `device_class: date` states carry no time or zone (`2026-08-03`), so they're parsed — and
    /// below, formatted — in UTC to keep the calendar day the server meant.
    private static let dateOnlyFormatter = with(ISO8601DateFormatter()) {
        $0.formatOptions = [.withFullDate]
    }

    /// Parses a timestamp state, with or without fractional seconds. Nil for the states that aren't
    /// timestamps at all (`unavailable`, `unknown`, or an entity that simply isn't datetime-backed).
    public static func date(from state: String) -> Date? {
        for formatter in timestampFormatters {
            if let parsed = formatter.date(from: state) {
                return parsed
            }
        }
        return nil
    }

    /// A localized relative description of a timestamp state — "In 56 minutes", "2 hours ago" — in
    /// the device's timezone. Nil when the state isn't a parsable timestamp, so callers can fall
    /// back to their usual rendering.
    public static func relativeDescription(for state: String) -> String? {
        guard let parsed = Self.date(from: state) else { return nil }
        // Built per call rather than cached: the formatter snapshots the current locale, and the
        // watch app outlives a region change.
        let formatter = RelativeDateTimeFormatter()
        return formatter.localizedString(for: parsed, relativeTo: Current.date())
    }

    /// A localized absolute description of a `device_class: date` state — "Aug 3, 2026". Nil when
    /// the state isn't a parsable date.
    public static func dateDescription(for state: String) -> String? {
        guard let parsed = dateOnlyFormatter.date(from: state) else { return nil }
        let formatter = with(DateFormatter()) {
            $0.dateStyle = .medium
            $0.timeStyle = .none
            $0.timeZone = TimeZone(secondsFromGMT: 0)
        }
        return formatter.string(from: parsed)
    }
}
