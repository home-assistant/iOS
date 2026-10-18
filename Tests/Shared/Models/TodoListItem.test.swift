import Foundation
import HAKit
@testable import Shared
import Testing

@Suite("TodoListItem due date parsing")
struct TodoListItemTests {
    /// 2026-08-27T00:30:00Z, i.e. 2026-08-26 19:30 in Central Daylight Time.
    private let instant = Date(timeIntervalSince1970: 1_787_790_600)

    private func decode(due: Any?) throws -> TodoListItem {
        var value: [String: Any] = [
            "summary": "Buy milk",
            "uid": "todo-1",
            "status": "needs_action",
        ]
        if let due {
            value["due"] = due
        }
        return try TodoListItem(data: HAData(value: value))
    }

    @Test("Honours the UTC offset the server sends instead of reading the time as UTC")
    func decodesOffsetDueDatetime() throws {
        let item = try decode(due: "2026-08-26T19:30:00-05:00")

        #expect(item.due == instant)
        #expect(item.hasDueTime)
    }

    @Test("A Z-suffixed due datetime is the same instant as its offset form")
    func decodesZuluDueDatetime() throws {
        let item = try decode(due: "2026-08-27T00:30:00Z")

        #expect(item.due == instant)
    }

    @Test("Fractional seconds do not defeat the offset-aware parse")
    func decodesFractionalDueDatetime() throws {
        let item = try decode(due: "2026-08-26T19:30:00.000-05:00")

        #expect(item.due == instant)
    }

    @Test("A due datetime without an offset is a local wall clock time")
    func decodesNaiveDueDatetimeInCurrentTimeZone() throws {
        let item = try decode(due: "2026-08-26T19:30:00")
        let due = try #require(item.due)
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: due)

        #expect(components.year == 2026)
        #expect(components.month == 8)
        #expect(components.day == 26)
        #expect(components.hour == 19)
        #expect(components.minute == 30)
    }

    @Test("An all-day due date is midnight in the current timezone")
    func decodesAllDayDueDate() throws {
        let item = try decode(due: "2026-08-26")
        let due = try #require(item.due)
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: due)

        #expect(!item.hasDueTime)
        #expect(components.year == 2026)
        #expect(components.month == 8)
        #expect(components.day == 26)
        #expect(components.hour == 0)
        #expect(components.minute == 0)
    }

    @Test("An item with no due date parses without one")
    func decodesMissingDue() throws {
        let item = try decode(due: nil)

        #expect(item.dueRaw == nil)
        #expect(item.due == nil)
        #expect(!item.hasDueTime)
    }

    @Test("An unparseable due string yields no date but keeps the raw value")
    func decodesMalformedDue() throws {
        let item = try decode(due: "not a date")

        #expect(item.dueRaw == "not a date")
        #expect(item.due == nil)
    }

    @Test("The canonical due string round-trips back to the same instant")
    func canonicalDueStringRoundTrips() {
        let canonical = TodoListItem.canonicalDueString(from: instant)

        #expect(TodoListItem.parseDueDateTime(canonical) == instant)
    }

    @Test("The canonical due string carries an offset so the server cannot read it as UTC")
    func canonicalDueStringCarriesOffset() {
        let canonical = TodoListItem.canonicalDueString(from: instant)
        let offsetSuffix = canonical.dropFirst("2026-08-26T19:30:00".count)

        #expect(offsetSuffix.hasPrefix("+") || offsetSuffix.hasPrefix("-") || offsetSuffix == "Z")
    }
}
