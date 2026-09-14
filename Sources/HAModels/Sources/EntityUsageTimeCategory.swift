import Foundation

/// The time-of-day buckets Home Assistant groups a user's interactions into.
///
/// The boundaries mirror the backend's `usage_prediction` integration: a `usage_prediction/
/// common_control` response only ever carries the bucket for the hour it was asked in, and says
/// nothing about which one that is, so the app has to agree with the backend on how an hour maps
/// to a bucket in order to file the response under the right one.
public enum EntityUsageTimeCategory: String, CaseIterable, Codable, Sendable {
    /// 06:00–11:59
    case morning
    /// 12:00–17:59
    case afternoon
    /// 18:00–21:59
    case evening
    /// 22:00–05:59
    case night

    /// The bucket an hour of the day belongs to. Hours outside `0..<24` land in `night`, which is
    /// the backend's own catch-all.
    public static func forHour(_ hour: Int) -> EntityUsageTimeCategory {
        switch hour {
        case 6 ..< 12:
            return .morning
        case 12 ..< 18:
            return .afternoon
        case 18 ..< 22:
            return .evening
        default:
            return .night
        }
    }

    /// The bucket a moment belongs to, read in the given calendar's time zone — the device's by
    /// default, which is the closest the app gets to the server's local time.
    public static func forDate(_ date: Date, calendar: Calendar = .current) -> EntityUsageTimeCategory {
        forHour(calendar.component(.hour, from: date))
    }
}
