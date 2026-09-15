import AppIntents
import Foundation

/// The union the calendar schema expects for an alarm: either an offset before the event or an
/// absolute date. Home Assistant reports neither, so this stays empty.
@available(iOS 27.0, *)
@UnionValue
enum EventAlarmCases {
    case duration(Duration)
    case date(Date)
}
