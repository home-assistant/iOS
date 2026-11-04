import Foundation

/// Which half of a 12-hour clock a time falls in. The frontend spells these "AM"/"PM" in the
/// `ha-base-time-input` select regardless of locale, so the raw values match.
public enum HADayPeriod: String, CaseIterable, Sendable {
    case am = "AM"
    case pm = "PM"
}
