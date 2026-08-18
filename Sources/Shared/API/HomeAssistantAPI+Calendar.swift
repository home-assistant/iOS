import Foundation

/// Calendar event fetching, mirroring the frontend's `fetchCalendarEvents` (`src/data/calendar.ts`).
///
/// Home Assistant only exposes a *subscription* over the WebSocket (`calendar/event/subscribe`);
/// the one-shot read is the REST endpoint, which is what the frontend uses too.
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

    private static let iso8601Formatter = ISO8601DateFormatter()
}
