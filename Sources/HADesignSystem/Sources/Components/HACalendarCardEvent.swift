import Foundation
import SwiftUI

/// One entry on an ``HACalendarCard``.
///
/// Frontend counterpart: the `CalendarEvent` `hui-calendar-card` hands to its full-calendar view,
/// rather than an element of its own.
public struct HACalendarCardEvent: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let start: Date
    public let end: Date
    /// Which calendar it came from, so several calendars on one card stay tellable apart.
    public let color: Color
    /// All-day events are written without a time, as the frontend does.
    public let isAllDay: Bool

    public init(
        id: String,
        title: String,
        start: Date,
        end: Date,
        color: Color = .haPrimary,
        isAllDay: Bool = false
    ) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.color = color
        self.isAllDay = isAllDay
    }
}

extension HACalendarCardEvent: FrontendComponent {
    public static var frontendComponentName: String { "hui-calendar-card" }
}
