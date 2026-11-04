import Foundation
@testable import Shared
import Testing

@Suite("HACalendarEvent decoding")
struct HACalendarEventTests {
    @Test("Decodes the REST shape, where boundaries are wrapped in dateTime objects")
    func decodesRestDateTimeShape() throws {
        let json = """
        [{
            "summary": "Standup",
            "start": {"dateTime": "2025-08-18T10:30:00-07:00"},
            "end": {"dateTime": "2025-08-18T11:00:00-07:00"},
            "description": "Daily sync",
            "location": "Office",
            "uid": "abc",
            "recurrence_id": "20250818",
            "rrule": "FREQ=DAILY"
        }]
        """
        let data = Data(json.utf8)
        let events = try JSONDecoder().decode([HACalendarEvent].self, from: data)
        let event = try #require(events.first)

        #expect(event.summary == "Standup")
        #expect(event.isAllDay == false)
        #expect(event.start.timeIntervalSince1970 == 1_755_538_200)
        #expect(event.end.timeIntervalSince1970 == 1_755_540_000)
        #expect(event.description == "Daily sync")
        #expect(event.location == "Office")
        #expect(event.uid == "abc")
        #expect(event.recurrenceId == "20250818")
        #expect(event.rrule == "FREQ=DAILY")
    }

    @Test("Decodes the subscription shape, where boundaries are plain strings")
    func decodesSubscriptionStringShape() throws {
        let json = """
        [{
            "summary": "Standup",
            "start": "2025-08-18T10:30:00-07:00",
            "end": "2025-08-18T11:00:00-07:00"
        }]
        """
        let data = Data(json.utf8)
        let events = try JSONDecoder().decode([HACalendarEvent].self, from: data)
        let event = try #require(events.first)

        #expect(event.isAllDay == false)
        #expect(event.start.timeIntervalSince1970 == 1_755_538_200)
        #expect(event.description == nil)
        #expect(event.location == nil)
    }

    @Test("Date-only boundaries mark the event all-day and anchor it to local midnight")
    func decodesAllDayEvent() throws {
        let json = """
        [{
            "summary": "Holiday",
            "start": {"date": "2025-08-18"},
            "end": {"date": "2025-08-19"}
        }]
        """
        let data = Data(json.utf8)
        let events = try JSONDecoder().decode([HACalendarEvent].self, from: data)
        let event = try #require(events.first)

        var components = DateComponents()
        components.year = 2025
        components.month = 8
        components.day = 18
        let expectedStart = try #require(Calendar.current.date(from: components))

        #expect(event.isAllDay)
        #expect(event.start == Calendar.current.startOfDay(for: expectedStart))
        // Home Assistant sends an exclusive end, so a one-day event ends the next midnight.
        #expect(event.end.timeIntervalSince(event.start) == 24 * 60 * 60)
    }

    @Test("Null optional fields decode as nil rather than failing")
    func decodesNullOptionals() throws {
        let json = """
        [{
            "summary": "Standup",
            "start": {"dateTime": "2025-08-18T10:30:00-07:00"},
            "end": {"dateTime": "2025-08-18T11:00:00-07:00"},
            "description": null,
            "location": null,
            "uid": null,
            "recurrence_id": null,
            "rrule": null
        }]
        """
        let data = Data(json.utf8)
        let events = try JSONDecoder().decode([HACalendarEvent].self, from: data)
        let event = try #require(events.first)

        #expect(event.description == nil)
        #expect(event.uid == nil)
        #expect(event.rrule == nil)
    }
}
