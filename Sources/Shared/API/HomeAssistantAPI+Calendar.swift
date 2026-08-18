import Foundation
import HAKit

/// Calendar reads and writes, mirroring `src/data/calendar.ts` in the frontend.
///
/// Reading is REST: Home Assistant only exposes a *subscription* over the WebSocket
/// (`calendar/event/subscribe`), so the one-shot read is the REST endpoint the frontend uses too.
/// Writing is the opposite — `calendar/event/create` and `calendar/event/delete` exist only as
/// WebSocket commands, there is no REST equivalent.
///
/// These must live in Shared, not in the app target: both the app binary and Shared.framework link
/// HAKit statically, so instantiating `HATypedRequest` metadata from app code mixes the two copies
/// of HAKit's type descriptors and the runtime returns null metadata (EXC_BAD_ACCESS). Inside
/// Shared the descriptors are consistent — same reasoning as `HomeAssistantAPI+TodoList`.
public extension HomeAssistantAPI {
    /// Events overlapping `[start, end)` for a single calendar entity.
    func calendarEvents(entityId: String, start: Date, end: Date) async throws -> [HACalendarEvent] {
        try await Self.calendarEvents(server: server, entityId: entityId, start: start, end: end)
    }

    static func calendarEvents(
        server: Server,
        entityId: String,
        start: Date,
        end: Date
    ) async throws -> [HACalendarEvent] {
        let data = try await HomeAssistantRESTClient.send(
            server: server,
            path: ["calendars", entityId],
            query: [
                URLQueryItem(name: "start", value: iso8601Formatter.string(from: start)),
                URLQueryItem(name: "end", value: iso8601Formatter.string(from: end)),
            ]
        )
        return try JSONDecoder().decode([HACalendarEvent].self, from: data)
    }

    /// Creates an event on `entityId`, taking the same fields the frontend's event editor offers.
    ///
    /// `end` is the *inclusive* end the user picked, matching how the editor presents it; Home
    /// Assistant stores an exclusive end, so an all-day event is sent through to the day after.
    func createCalendarEvent(
        entityId: String,
        summary: String,
        description: String?,
        location: String?,
        rrule: String?,
        start: Date,
        end: Date,
        isAllDay: Bool
    ) async throws {
        var event: [String: Any] = [
            "summary": summary,
            "dtstart": Self.boundary(start, isAllDay: isAllDay, isExclusiveEnd: false),
            "dtend": Self.boundary(end, isAllDay: isAllDay, isExclusiveEnd: true),
        ]
        if let description, !description.isEmpty { event["description"] = description }
        if let location, !location.isEmpty { event["location"] = location }
        if let rrule, !rrule.isEmpty { event["rrule"] = rrule }

        _ = try await send(HATypedRequest<HAResponseVoid>(request: .init(
            type: "calendar/event/create",
            data: [
                "entity_id": entityId,
                "event": event,
            ]
        )))
    }

    /// Deletes an event from `entityId`.
    ///
    /// `recurrenceId` and `recurrenceRange` only apply to recurring events: an empty range deletes
    /// the single occurrence, `THISANDFUTURE` deletes it and everything after it.
    func deleteCalendarEvent(
        entityId: String,
        uid: String,
        recurrenceId: String?,
        recurrenceRange: String?
    ) async throws {
        var data: [String: Any] = [
            "entity_id": entityId,
            "uid": uid,
        ]
        if let recurrenceId, !recurrenceId.isEmpty { data["recurrence_id"] = recurrenceId }
        if let recurrenceRange, !recurrenceRange.isEmpty { data["recurrence_range"] = recurrenceRange }

        _ = try await send(HATypedRequest<HAResponseVoid>(request: .init(
            type: "calendar/event/delete",
            data: data
        )))
    }

    /// Formats one end of an event the way `calendar/event/create` expects.
    ///
    /// All-day events are plain `yyyy-MM-dd` dates, and the stored end is exclusive, so the
    /// inclusive end the user picked is moved on by a day (the frontend does the same in
    /// `_calculateData`). Timed events are sent as ISO8601 *with* the UTC offset rather than the
    /// naive local datetime the frontend sends — the frontend knows `hass.config.time_zone` and the
    /// app does not persist it, and an explicit offset is unambiguous either way.
    private static func boundary(_ date: Date, isAllDay: Bool, isExclusiveEnd: Bool) -> String {
        guard isAllDay else { return iso8601Formatter.string(from: date) }
        let day = isExclusiveEnd
            ? Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
            : date
        return dayFormatter.string(from: day)
    }

    private func send<T: HADataDecodable>(_ request: HATypedRequest<T>) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            connection.send(request) { result in
                switch result {
                case let .success(value):
                    continuation.resume(returning: value)
                case let .failure(error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static let iso8601Formatter = ISO8601DateFormatter()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
