import Foundation
import GRDB
import HAKit
@testable import Shared

/// Stands in for the server-backed calendars model: records every read and, like the real one,
/// leaves what the server returned in the cache. Nothing is pruned, so seeded events stay put.
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
            return stubbedRecords[calendar.id] ?? []
        }
        if !records.isEmpty {
            try? await Current.database().write { db in
                for record in records {
                    try record.insert(db, onConflict: .replace)
                }
            }
        }
        return records.map(\.event)
    }
}
