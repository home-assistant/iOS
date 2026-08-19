import Foundation
import Shared
import SwiftUI

/// The weekday-over-day-number block the iOS Calendar widget leads with, tinted with the Home
/// Assistant accent instead of the Calendar app's red.
struct WidgetCalendarDateBadge: View {
    let date: Date
    let calendar: Calendar

    var body: some View {
        VStack(alignment: .leading, spacing: -DesignSystem.Spaces.micro) {
            Text(verbatim: WidgetCalendarFormatter.weekdayAbbreviation(date, calendar: calendar))
                .font(DesignSystem.Font.caption2.weight(.heavy))
                .foregroundStyle(.haPrimary)
            Text(verbatim: WidgetCalendarFormatter.dayNumber(date, calendar: calendar))
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
        }
        .minimumScaleFactor(0.8)
        .lineLimit(1)
    }
}

#Preview {
    WidgetCalendarDateBadge(date: Date(), calendar: .current)
        .padding()
}
