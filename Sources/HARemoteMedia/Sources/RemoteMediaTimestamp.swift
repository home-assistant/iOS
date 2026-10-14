import Foundation

/// Reads the timestamps Home Assistant writes into `media_position_updated_at`: Core serializes the
/// `datetime` with `isoformat()`, such as `2026-09-06T12:00:00+00:00`, with fractional seconds when
/// there are any. The same pair of formatters the app uses elsewhere for Home Assistant timestamps.
enum RemoteMediaTimestamp {
    private static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let whole: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// Seconds since 1970-01-01 UTC, or `nil` when `text` is not a timestamp.
    static func unixSeconds(from text: String) -> TimeInterval? {
        (fractional.date(from: text) ?? whole.date(from: text))?.timeIntervalSince1970
    }
}
