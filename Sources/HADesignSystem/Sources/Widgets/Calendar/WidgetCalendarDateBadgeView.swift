#if !os(watchOS)
import Foundation
import SwiftUI

/// The weekday-over-day-number block the iOS Calendar widget leads with, tinted with the Home
/// Assistant accent instead of the Calendar app's red.
public struct WidgetCalendarDateBadgeView: View {
    private let date: Date
    private let calendar: Calendar

    public init(date: Date, calendar: Calendar) {
        self.date = date
        self.calendar = calendar
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: -DesignSystem.Spaces.micro) {
            Text(verbatim: WidgetCalendarText.weekdayAbbreviation(date, calendar: calendar))
                .font(DesignSystem.Font.caption2.weight(.heavy))
                .foregroundStyle(.haPrimary)
            Text(verbatim: WidgetCalendarText.dayNumber(date, calendar: calendar))
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .minimumScaleFactor(0.8)
        .lineLimit(1)
    }
}

#Preview {
    WidgetCalendarDateBadgeView(date: Date(), calendar: .current)
        .padding()
}
#endif
