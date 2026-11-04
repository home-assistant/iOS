import GRDB
import HAModels
@testable import Shared
import SharedTesting
import Testing

@Suite(.sharedState)
struct HACalendarEventRecordTests {
    private let serverId = "server"
    private let calendarEntityId = "calendar.household"
    /// Monday 18 August 2025, 08:00 UTC.
    private let windowStart = Date(timeIntervalSince1970: 1_755_504_000)
    private var windowEnd: Date { windowStart.addingTimeInterval(14 * 24 * 60 * 60) }

    @Test("Replacing a window drops cached rows that overlap it, even ones that started earlier")
    func replaceDropsOverlappingRows() async throws {
        try await withDatabase {
            let ongoing = record(
                summary: "Ongoing",
                start: windowStart.addingTimeInterval(-3600),
                end: windowStart.addingTimeInterval(3600)
            )
            let finished = record(
                summary: "Finished",
                start: windowStart.addingTimeInterval(-7200),
                end: windowStart.addingTimeInterval(-3600)
            )
            await HACalendarEventRecord.replace(
                [ongoing, finished],
                serverId: serverId,
                calendarEntityId: calendarEntityId,
                start: windowStart.addingTimeInterval(-7200),
                end: windowEnd
            )

            let renamed = record(summary: "Ongoing, renamed", start: ongoing.start, end: ongoing.end)
            await HACalendarEventRecord.replace(
                [renamed],
                serverId: serverId,
                calendarEntityId: calendarEntityId,
                start: windowStart,
                end: windowEnd
            )

            let cached = await HACalendarEventRecord.events(
                serverId: serverId,
                calendarEntityId: calendarEntityId,
                start: windowStart.addingTimeInterval(-7200),
                end: windowEnd
            )
            #expect(cached.map(\.summary) == ["Finished", "Ongoing, renamed"])
        }
    }

    @Test("Events without a uid at the same time are cached separately")
    func cachesSameTimeEventsWithoutUidSeparately() async throws {
        try await withDatabase {
            let start = windowStart.addingTimeInterval(3600)
            let end = start.addingTimeInterval(3600)
            await HACalendarEventRecord.replace(
                [
                    record(summary: "Take out trash", start: start, end: end),
                    record(summary: "Put check out for yard guys", start: start, end: end),
                    record(summary: "Empty uid counts as none", uid: "", start: start, end: end),
                ],
                serverId: serverId,
                calendarEntityId: calendarEntityId,
                start: windowStart,
                end: windowEnd
            )

            let cached = await HACalendarEventRecord.events(
                serverId: serverId,
                calendarEntityId: calendarEntityId,
                start: windowStart,
                end: windowEnd
            )
            #expect(cached.count == 3)
            #expect(Set(cached.map(\.id)).count == 3)
        }
    }

    private func record(
        summary: String,
        uid: String? = nil,
        start: Date,
        end: Date
    ) -> HACalendarEventRecord {
        HACalendarEventRecord(
            id: HACalendarEventRecord.uniqueId(
                serverId: serverId,
                calendarEntityId: calendarEntityId,
                uid: uid,
                recurrenceId: nil,
                start: start,
                end: end,
                summary: summary
            ),
            serverId: serverId,
            calendarEntityId: calendarEntityId,
            uid: uid,
            recurrenceId: nil,
            summary: summary,
            start: start,
            end: end,
            isAllDay: false,
            eventDescription: nil,
            location: nil,
            rrule: nil
        )
    }

    private func withDatabase(perform work: () async throws -> Void) async throws {
        let previousDatabase = Current.database
        let previousDate = Current.date
        let database = try DatabaseQueue(path: ":memory:")
        try HACalendarEventTable().createIfNeeded(database: database)
        Current.database = { database }
        // Pinned so the retention cleanup in `replace` doesn't drop the rows under test.
        Current.date = { [windowStart] in windowStart }
        defer {
            Current.database = previousDatabase
            Current.date = previousDate
        }
        try await work()
    }
}
