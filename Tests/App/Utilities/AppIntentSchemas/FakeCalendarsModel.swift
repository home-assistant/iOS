import Foundation
import HAKit
@testable import Shared

/// Stands in for the server-backed calendars model: records every read, and answers the way the
/// real one does. A calendar given a server answer replaces its cached window with it; a calendar
/// without one is unreachable and falls back to what the cache holds.
final class FakeCalendarsModel: HACalendarsModelProtocol {
    struct EventsRequest: Equatable {
        let calendar: HACalendar
        let start: Date
        let end: Date

        func covers(_ date: Date) -> Bool {
            start <= date && date < end
        }
    }

    private let lock = NSLock()
    private var recordedRequests: [EventsRequest] = []
    private var stubbedRecords: [String: [HACalendarEventRecord]] = [:]

    var eventsRequests: [EventsRequest] {
        lock.withLock { recordedRequests }
    }

    var refreshedCalendars: [HACalendar] {
        lock.withLock { recordedRequests.map(\.calendar) }
    }

    func serverReturns(_ records: [HACalendarEventRecord], for calendar: HACalendar) {
        lock.withLock { stubbedRecords[calendar.id] = records }
    }

    func updateModel(_ entities: [HAEntity], server: Server) async {}

    func refresh(server: Server) async -> Bool {
        true
    }

    func events(for calendar: HACalendar, start: Date, end: Date) async -> [HACalendarEvent] {
        let records = lock.withLock {
            recordedRequests.append(EventsRequest(calendar: calendar, start: start, end: end))
            return stubbedRecords[calendar.id]
        }
        guard let records else {
            return await HACalendarEventRecord.events(
                serverId: calendar.serverId,
                calendarEntityId: calendar.entityId,
                start: start,
                end: end
            ).map(\.event)
        }
        await HACalendarEventRecord.replace(
            records,
            serverId: calendar.serverId,
            calendarEntityId: calendar.entityId,
            start: start,
            end: end
        )
        return records.map(\.event)
    }
}
