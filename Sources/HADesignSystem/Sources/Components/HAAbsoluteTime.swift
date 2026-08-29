#if !os(watchOS)
import SwiftUI

/// A timestamp written the shortest way that is still unambiguous. The SwiftUI counterpart of the
/// frontend's `ha-absolute-time`.
///
/// The rule comes from `absoluteTime()`: drop whatever the reader can infer. Something that
/// happened today needs only a clock time; something earlier this year needs the day and month;
/// only last year's events carry a year. An absent timestamp reads as "Never".
///
/// Both instants are parameters — `date` and the `now` it is measured against — for the same
/// reason ``HARelativeTime`` takes both: a view that read the clock itself would render differently
/// on every pass and could not be snapshotted.
public struct HAAbsoluteTime: View {
    @Environment(\.locale) private var locale
    @Environment(\.timeZone) private var timeZone
    @Environment(\.calendar) private var calendar

    private let date: Date?
    private let now: Date

    public init(date: Date?, now: Date) {
        self.date = date
        self.now = now
    }

    private var text: String {
        guard let date else {
            return HADesignSystemEnvironment.current.strings.never
        }
        var referenceCalendar = calendar
        referenceCalendar.timeZone = timeZone
        referenceCalendar.locale = locale

        if referenceCalendar.isDate(date, inSameDayAs: now) {
            return date.formatted(
                Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, timeZone: timeZone)
            )
        }
        let sameYear = referenceCalendar.component(.year, from: date)
            == referenceCalendar.component(.year, from: now)
        // `.abbreviated` keeps the year; the frontend's same-year format drops it, so the day and
        // month are spelled out explicitly rather than asking for a canned date style.
        let dateStyle: Date.FormatStyle = sameYear
            ? Date.FormatStyle(locale: locale, timeZone: timeZone).day().month(.abbreviated)
            : Date.FormatStyle(locale: locale, timeZone: timeZone).day().month(.abbreviated).year()
        let time = Date.FormatStyle(date: .omitted, time: .shortened, locale: locale, timeZone: timeZone)
        return "\(date.formatted(dateStyle)) \(date.formatted(time))"
    }

    public var body: some View {
        Text(text)
    }
}

/// 2026-08-29 09:41:07 UTC, the instant the rest of the gallery pins.
private let sampleNow = Date(timeIntervalSince1970: 1_787_996_467)

#Preview {
    VStack(alignment: .leading, spacing: DesignSystem.Spaces.one) {
        HAAbsoluteTime(date: sampleNow.addingTimeInterval(-3600), now: sampleNow)
        HAAbsoluteTime(date: sampleNow.addingTimeInterval(-86400 * 3), now: sampleNow)
        HAAbsoluteTime(date: sampleNow.addingTimeInterval(-86400 * 400), now: sampleNow)
        HAAbsoluteTime(date: nil, now: sampleNow)
    }
    .padding()
}

extension HAAbsoluteTime: FrontendComponent {
    public static var frontendComponentName: String { "ha-absolute-time" }
    public static var frontendComponentVersion: String { "2026-08-28" }
}

#endif
