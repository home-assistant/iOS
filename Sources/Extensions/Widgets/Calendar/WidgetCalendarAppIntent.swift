import AppIntents
import Foundation
import Shared

@available(iOS 17.0, *)
struct WidgetCalendarAppIntent: AppIntent, WidgetConfigurationIntent {
    static let title: LocalizedStringResource = .init("widgets.calendar.title", defaultValue: "Calendar")
    static let description = IntentDescription(
        .init("widgets.calendar.description", defaultValue: "See what is coming up on your calendars.")
    )

    static var isDiscoverable: Bool = false

    /// Unbounded on purpose: how many events fit is a function of the widget family, but how many
    /// calendars they are merged from is not, and a household that keeps one calendar per person
    /// should be able to select all of them even in the small family.
    @Parameter(
        title: .init("widgets.calendar.parameter.calendars", defaultValue: "Calendars")
    )
    var calendars: [WidgetCalendarAppEntity]?

    /// Off by default because the common case is one household calendar, where repeating its name
    /// under every event is noise. Turning it on is what makes a merged widget readable.
    @Parameter(
        title: .init("widgets.calendar.parameter.show_calendar_name", defaultValue: "Show calendar name"),
        default: false
    )
    var showsCalendarName: Bool

    static var parameterSummary: some ParameterSummary {
        Summary {
            \.$calendars
            \.$showsCalendarName
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<Bool> {
        .result(value: true)
    }
}
