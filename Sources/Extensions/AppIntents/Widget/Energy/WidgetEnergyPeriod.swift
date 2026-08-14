import AppIntents
import Foundation

/// The time window the Energy widget summarises. Drives both the statistics query range and the
/// chart's bucketing granularity.
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
enum WidgetEnergyPeriod: String, Codable, Sendable, AppEnum {
    case today
    case yesterday
    case thisWeek
    case thisMonth

    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: .init("widgets.energy.period.title", defaultValue: "Period")
    )
    static var caseDisplayRepresentations: [WidgetEnergyPeriod: DisplayRepresentation] = [
        .today: DisplayRepresentation(title: .init("widgets.energy.period.today", defaultValue: "Today")),
        .yesterday: DisplayRepresentation(title: .init("widgets.energy.period.yesterday", defaultValue: "Yesterday")),
        .thisWeek: DisplayRepresentation(title: .init("widgets.energy.period.this_week", defaultValue: "This week")),
        .thisMonth: DisplayRepresentation(title: .init("widgets.energy.period.this_month", defaultValue: "This month")),
    ]

    /// Localised name reused in the widget UI header.
    var displayTitle: LocalizedStringResource {
        Self.caseDisplayRepresentations[self]?.title ?? .init(stringLiteral: rawValue)
    }

    /// Statistics bucketing: hourly for single-day windows (for the 24h chart), daily otherwise.
    var statisticsPeriod: String {
        switch self {
        case .today, .yesterday: "hour"
        case .thisWeek, .thisMonth: "day"
        }
    }

    /// Hour of the day before which "today" has too little behind it to be worth showing on its own.
    static let earlyMorningHour = 5

    /// The window to fall back to when the selected one came back without any data. Before
    /// ``earlyMorningHour`` "today" is usually empty simply because the day just started, so the
    /// widget summarises the day before instead — exactly as if "Yesterday" had been picked.
    /// Nil for every other case: an empty window is the honest answer there.
    func emptyDataFallback(now: Date, calendar: Calendar = .current) -> WidgetEnergyPeriod? {
        guard self == .today, calendar.component(.hour, from: now) < Self.earlyMorningHour else {
            return nil
        }
        return .yesterday
    }

    /// The `[start, end)` range for the window, anchored to the user's calendar.
    func dateRange(now: Date, calendar: Calendar = .current) -> (start: Date, end: Date) {
        let startOfToday = calendar.startOfDay(for: now)
        switch self {
        case .today:
            return (startOfToday, now)
        case .yesterday:
            let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday
            return (startOfYesterday, startOfToday)
        case .thisWeek:
            let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? startOfToday
            return (start, now)
        case .thisMonth:
            let start = calendar.dateInterval(of: .month, for: now)?.start ?? startOfToday
            return (start, now)
        }
    }
}
