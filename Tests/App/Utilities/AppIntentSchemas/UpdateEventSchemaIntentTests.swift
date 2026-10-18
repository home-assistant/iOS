@testable import HomeAssistant
@testable import Shared
import XCTest

/// Editing an event on a Home Assistant calendar.
///
/// `calendar/event/update` replaces the whole event, so the interesting part is what the intent
/// refills for the fields the caller left out.
@available(iOS 27.0, *)
final class UpdateEventSchemaIntentTests: AppIntentSchemaTestCase {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func existingEvent(
        calendar: HACalendar,
        uid: String? = "uid-1",
        recurrenceId: String? = nil
    ) throws -> CalendarEventSchemaEntity {
        let record = try seedEvent(
            uid: uid,
            recurrenceId: recurrenceId,
            summary: "Dentist",
            start: start,
            end: start.addingTimeInterval(3600),
            eventDescription: "Bring the form",
            location: "High Street"
        )
        return CalendarEventSchemaEntity(record: record, calendar: CalendarSchemaEntity(calendar: calendar))
    }

    private func intent(for event: CalendarEventSchemaEntity) -> UpdateEventSchemaIntent {
        let intent = UpdateEventSchemaIntent()
        intent.event = event
        return intent
    }

    func testTheEventIsAddressedByItsUidOnItsOwnCalendar() async throws {
        let calendar = try seedCalendar(entityId: "calendar.home", supportedFeatures: 4)
        let sut = try intent(for: existingEvent(calendar: calendar))
        sut.title = "Dentist (moved)"

        let task = Task { try await sut.perform() }
        let pending = try await request()

        XCTAssertEqual(pending.request.type.command, "calendar/event/update")
        XCTAssertEqual(pending.request.data["entity_id"] as? String, "calendar.home")
        XCTAssertEqual(pending.request.data["uid"] as? String, "uid-1")
        XCTAssertEqual((pending.request.data["event"] as? [String: Any])?["summary"] as? String, "Dentist (moved)")

        pending.completion(.success(.dictionary([:])))
        _ = try await task.value
    }

    /// The update replaces the whole event, so a field the caller did not mention has to be sent
    /// back as it stands rather than cleared.
    func testFieldsTheCallerLeftOutAreRefilledFromTheEvent() async throws {
        let calendar = try seedCalendar(supportedFeatures: 4)
        let sut = try intent(for: existingEvent(calendar: calendar))

        let task = Task { try await sut.perform() }
        let pending = try await request()
        let event = pending.request.data["event"] as? [String: Any]
        let formatter = ISO8601DateFormatter()

        XCTAssertEqual(event?["summary"] as? String, "Dentist")
        XCTAssertEqual(event?["description"] as? String, "Bring the form")
        XCTAssertEqual(event?["location"] as? String, "High Street")
        XCTAssertEqual(formatter.date(from: event?["dtstart"] as? String ?? ""), start)
        XCTAssertEqual(formatter.date(from: event?["dtend"] as? String ?? ""), start.addingTimeInterval(3600))

        pending.completion(.success(.dictionary([:])))
        _ = try await task.value
    }

    func testANewLocationAndNoteReplaceTheStoredOnes() async throws {
        let calendar = try seedCalendar(supportedFeatures: 4)
        let sut = try intent(for: existingEvent(calendar: calendar))
        sut.location = .text("Low Street")
        sut.note = "Bring nothing"

        let task = Task { try await sut.perform() }
        let pending = try await request()
        let event = pending.request.data["event"] as? [String: Any]

        XCTAssertEqual(event?["location"] as? String, "Low Street")
        XCTAssertEqual(event?["description"] as? String, "Bring nothing")

        pending.completion(.success(.dictionary([:])))
        _ = try await task.value
    }

    /// One occurrence carries no range; this one and everything after it carries `THISANDFUTURE`.
    func testTheSpanBecomesTheRecurrenceRange() async throws {
        let calendar = try seedCalendar(supportedFeatures: 4)
        let sut = try intent(for: existingEvent(calendar: calendar, recurrenceId: "rec-1"))
        sut.span = .future

        let task = Task { try await sut.perform() }
        let pending = try await request()

        XCTAssertEqual(pending.request.data["recurrence_id"] as? String, "rec-1")
        XCTAssertEqual(pending.request.data["recurrence_range"] as? String, "THISANDFUTURE")

        pending.completion(.success(.dictionary([:])))
        _ = try await task.value
    }

    func testASingleOccurrenceSendsNoRange() async throws {
        let calendar = try seedCalendar(supportedFeatures: 4)
        let sut = try intent(for: existingEvent(calendar: calendar, recurrenceId: "rec-1"))
        sut.span = .this

        let task = Task { try await sut.perform() }
        let pending = try await request()

        XCTAssertNil(pending.request.data["recurrence_range"])

        pending.completion(.success(.dictionary([:])))
        _ = try await task.value
    }

    /// Turning a timed event into an all-day one has to re-derive the end, or the stored exclusive
    /// end would be a day short.
    func testSwitchingToAllDaySendsDays() async throws {
        let calendar = try seedCalendar(supportedFeatures: 4)
        let sut = try intent(for: existingEvent(calendar: calendar))
        sut.isAllDay = true

        let task = Task { try await sut.perform() }
        let pending = try await request()
        let event = pending.request.data["event"] as? [String: Any]

        XCTAssertEqual(event?["dtstart"] as? String, HACalendarEvent.dayFormatter.string(from: start))

        pending.completion(.success(.dictionary([:])))
        _ = try await task.value
    }

    /// Moving an event between calendars is a delete plus a create in Home Assistant, which is not
    /// what an edit promises, so the event stays where it is.
    func testANamedCalendarDoesNotMoveTheEvent() async throws {
        let home = try seedCalendar(entityId: "calendar.home", supportedFeatures: 4, sortOrder: 0)
        let work = try seedCalendar(entityId: "calendar.work", supportedFeatures: 4, sortOrder: 1)
        let sut = try intent(for: existingEvent(calendar: home))
        sut.calendar = CalendarSchemaEntity(calendar: work)

        let task = Task { try await sut.perform() }
        let pending = try await request()

        XCTAssertEqual(pending.request.data["entity_id"] as? String, "calendar.home")

        pending.completion(.success(.dictionary([:])))
        _ = try await task.value
    }

    func testAnEventWithoutAUidCannotBeEdited() async throws {
        let calendar = try seedCalendar(supportedFeatures: 4)
        let sut = try intent(for: existingEvent(calendar: calendar, uid: nil))

        do {
            _ = try await sut.perform()
            XCTFail("expected an event with no identifier to be refused")
        } catch {
            XCTAssertEqual(
                (error as? ShortcutAppIntentError)?.errorDescription,
                L10n.AppIntents.Calendar.Error.eventNotEditable("Dentist")
            )
        }
        XCTAssertTrue(connection.pendingRequests.isEmpty)
    }

    func testACalendarThatCannotEditEventsIsRefused() async throws {
        let calendar = try seedCalendar(name: "Holidays", supportedFeatures: 1)
        let sut = try intent(for: existingEvent(calendar: calendar))

        do {
            _ = try await sut.perform()
            XCTFail("expected a calendar without updateEvent to be refused")
        } catch {
            XCTAssertEqual(
                (error as? ShortcutAppIntentError)?.errorDescription,
                L10n.AppIntents.Calendar.Error.updateUnsupported("Holidays")
            )
        }
        XCTAssertTrue(connection.pendingRequests.isEmpty)
    }

    /// A moved event has to leave the cache where it was as well as appear where it now is, so the
    /// read-back takes in both dates.
    func testTheCalendarIsReadBackAroundBothTheOldAndTheNewDates() async throws {
        let calendar = try seedCalendar(supportedFeatures: 4)
        let sut = try intent(for: existingEvent(calendar: calendar))
        let movedTo = start.addingTimeInterval(45 * 86400)
        sut.startDate = movedTo
        sut.endDate = movedTo.addingTimeInterval(3600)

        let task = Task { try await sut.perform() }
        let pending = try await request()
        XCTAssertTrue(calendarsModel.eventsRequests.isEmpty)

        pending.completion(.success(.dictionary([:])))
        _ = try await task.value

        let readBack = try XCTUnwrap(calendarsModel.eventsRequests.first)
        XCTAssertEqual(calendarsModel.refreshedCalendars.map(\.id), [calendar.id])
        XCTAssertTrue(readBack.covers(start))
        XCTAssertTrue(readBack.covers(movedTo))
    }

    func testTheStoredEventIsHandedBackWhenTheReadBackFindsIt() async throws {
        let calendar = try seedCalendar(supportedFeatures: 4)
        let sut = try intent(for: existingEvent(calendar: calendar))
        sut.title = "Dentist (moved)"
        calendarsModel.serverReturns([
            HACalendarEventRecord(
                id: "stored",
                serverId: serverId,
                calendarEntityId: calendar.entityId,
                uid: "uid-1",
                recurrenceId: nil,
                summary: "Dentist (moved)",
                start: start,
                end: start.addingTimeInterval(3600),
                isAllDay: false,
                eventDescription: "Bring the form",
                location: "High Street",
                rrule: nil
            ),
        ], for: calendar)

        let task = Task { try await sut.perform() }
        try await acknowledge()
        _ = try await task.value

        let stored = await CalendarSchemaSupport.cachedEvent(
            on: calendar,
            titled: "Dentist (moved)",
            start: start,
            end: start.addingTimeInterval(3600),
            isAllDay: false,
            uid: "uid-1"
        )
        XCTAssertEqual(stored?.id, "stored")
    }
}
