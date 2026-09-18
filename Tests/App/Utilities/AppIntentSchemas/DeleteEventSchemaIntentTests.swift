@testable import HomeAssistant
@testable import Shared
import XCTest

/// Removing an event from a Home Assistant calendar.
@available(iOS 27.0, *)
final class DeleteEventSchemaIntentTests: AppIntentSchemaTestCase {
    private func intent(
        calendar: HACalendar,
        uid: String? = "uid-1",
        recurrenceId: String? = nil
    ) throws -> DeleteEventSchemaIntent {
        let record = try seedEvent(uid: uid, recurrenceId: recurrenceId, summary: "Dentist")
        let intent = DeleteEventSchemaIntent()
        intent.entity = CalendarEventSchemaEntity(
            record: record,
            calendar: CalendarSchemaEntity(calendar: calendar)
        )
        return intent
    }

    func testTheEventIsDeletedByItsUidOnItsOwnCalendar() async throws {
        let calendar = try seedCalendar(entityId: "calendar.home", supportedFeatures: 2)
        let sut = try intent(calendar: calendar)

        let task = Task { try await sut.perform() }
        let pending = try await request()

        XCTAssertEqual(pending.request.type.command, "calendar/event/delete")
        XCTAssertEqual(pending.request.data["entity_id"] as? String, "calendar.home")
        XCTAssertEqual(pending.request.data["uid"] as? String, "uid-1")
        XCTAssertNil(pending.request.data["recurrence_range"])

        pending.completion(.success(.dictionary([:])))
        _ = try await task.value
    }

    func testDeletingFromHereOnCarriesTheRange() async throws {
        let calendar = try seedCalendar(supportedFeatures: 2)
        let sut = try intent(calendar: calendar, recurrenceId: "rec-1")
        sut.span = .future

        let task = Task { try await sut.perform() }
        let pending = try await request()

        XCTAssertEqual(pending.request.data["recurrence_id"] as? String, "rec-1")
        XCTAssertEqual(pending.request.data["recurrence_range"] as? String, "THISANDFUTURE")

        pending.completion(.success(.dictionary([:])))
        _ = try await task.value
    }

    func testAnEventWithoutAUidCannotBeDeleted() async throws {
        let calendar = try seedCalendar(supportedFeatures: 2)
        let sut = try intent(calendar: calendar, uid: nil)

        do {
            _ = try await sut.perform()
            XCTFail("expected an event with no identifier to be refused")
        } catch {
            XCTAssertEqual(
                (error as? ShortcutAppIntentError)?.errorDescription,
                L10n.AppIntents.Calendar.Error.eventNotDeletable("Dentist")
            )
        }
        XCTAssertTrue(connection.pendingRequests.isEmpty)
    }

    func testACalendarThatCannotDeleteEventsIsRefused() async throws {
        let calendar = try seedCalendar(name: "Holidays", supportedFeatures: 1)
        let sut = try intent(calendar: calendar)

        do {
            _ = try await sut.perform()
            XCTFail("expected a calendar without deleteEvent to be refused")
        } catch {
            XCTAssertEqual(
                (error as? ShortcutAppIntentError)?.errorDescription,
                L10n.AppIntents.Calendar.Error.deleteUnsupported("Holidays")
            )
        }
        XCTAssertTrue(connection.pendingRequests.isEmpty)
    }

    func testTheCalendarIsReadBackOnceTheEventIsDeleted() async throws {
        let calendar = try seedCalendar(supportedFeatures: 2)
        let sut = try intent(calendar: calendar)

        let task = Task { try await sut.perform() }
        let pending = try await request()
        XCTAssertTrue(calendarsModel.eventsRequests.isEmpty)

        pending.completion(.success(.dictionary([:])))
        _ = try await task.value

        let readBack = try XCTUnwrap(calendarsModel.eventsRequests.first)
        XCTAssertEqual(calendarsModel.refreshedCalendars.map(\.id), [calendar.id])
        XCTAssertTrue(readBack.covers(Date(timeIntervalSince1970: 1_700_000_000)))
    }
}
