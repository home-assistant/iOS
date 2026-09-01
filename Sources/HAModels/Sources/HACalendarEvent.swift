import Foundation

/// A single event returned by Home Assistant's calendar API.
///
/// Both the REST endpoint (`GET /api/calendars/{entity_id}`) and the `calendar/event/subscribe`
/// WebSocket command return the same fields, but they encode the boundaries differently: REST wraps
/// them in `{"dateTime": …}` / `{"date": …}` objects while the subscription sends bare strings. The
/// decoder accepts both, the same way the frontend's `normalizeSubscriptionEventData` does.
public struct HACalendarEvent: Decodable, Identifiable, Hashable {
    /// Stable id for the event. Recurring events repeat their `uid`, so the occurrence's start is
    /// folded in to keep each instance distinct.
    public var id: String {
        [uid, recurrenceId, String(start.timeIntervalSince1970), summary]
            .compactMap { $0 }
            .joined(separator: "-")
    }

    public let summary: String
    public let start: Date
    /// For all-day events this is the exclusive end date Home Assistant sends, matching iCalendar:
    /// a single-day event ends on the following day.
    public let end: Date
    /// `true` when Home Assistant sent dates rather than date-times.
    public let isAllDay: Bool
    public let description: String?
    public let location: String?
    public let uid: String?
    public let recurrenceId: String?
    public let rrule: String?

    public init(
        summary: String,
        start: Date,
        end: Date,
        isAllDay: Bool,
        description: String? = nil,
        location: String? = nil,
        uid: String? = nil,
        recurrenceId: String? = nil,
        rrule: String? = nil
    ) {
        self.summary = summary
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.description = description
        self.location = location
        self.uid = uid
        self.recurrenceId = recurrenceId
        self.rrule = rrule
    }

    private enum CodingKeys: String, CodingKey {
        case summary
        case start
        case end
        case description
        case location
        case uid
        case recurrenceId = "recurrence_id"
        case rrule
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let start = try container.decode(Boundary.self, forKey: .start)
        let end = try container.decode(Boundary.self, forKey: .end)
        self.summary = (try? container.decode(String.self, forKey: .summary)) ?? ""
        self.start = start.date
        self.end = end.date
        self.isAllDay = start.isAllDay
        // `try?` rather than plain `decodeIfPresent` on purpose. Missing keys and explicit `null`
        // are already covered; what this additionally tolerates is a wrong *type* from an
        // integration that fills these fields itself. Decoding a list fails as a whole, so letting
        // one odd `location` throw would empty the entire month instead of dropping one field —
        // the same failure the device registry hit when a single malformed identifier killed the
        // whole fetch (#5113). The fields that must be trustworthy — `start` and `end` — still throw.
        self.description = try? container.decodeIfPresent(String.self, forKey: .description)
        self.location = try? container.decodeIfPresent(String.self, forKey: .location)
        self.uid = try? container.decodeIfPresent(String.self, forKey: .uid)
        self.recurrenceId = try? container.decodeIfPresent(String.self, forKey: .recurrenceId)
        self.rrule = try? container.decodeIfPresent(String.self, forKey: .rrule)
    }

    /// One end of an event, in any of the three shapes Home Assistant emits: a bare string
    /// (subscription), `{"dateTime": …}` or `{"date": …}` (REST).
    private struct Boundary: Decodable {
        let date: Date
        let isAllDay: Bool

        private enum CodingKeys: String, CodingKey {
            case dateTime
            case date
        }

        init(from decoder: Decoder) throws {
            if let raw = try? decoder.singleValueContainer().decode(String.self) {
                try self.init(raw: raw)
                return
            }
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let dateTime = try container.decodeIfPresent(String.self, forKey: .dateTime) {
                try self.init(raw: dateTime)
            } else if let date = try container.decodeIfPresent(String.self, forKey: .date) {
                try self.init(raw: date)
            } else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Calendar event boundary has neither dateTime nor date"
                ))
            }
        }

        /// Date-only values (`yyyy-MM-dd`) mark all-day events and are anchored to midnight local
        /// time; anything longer is a full ISO8601 date-time that already carries its own offset.
        private init(raw: String) throws {
            if let date = HACalendarEvent.dayFormatter.date(from: raw) {
                self.date = date
                self.isAllDay = true
                return
            }
            if let date = HACalendarEvent.dateTime(from: raw) {
                self.date = date
                self.isAllDay = false
                return
            }
            throw DecodingError.dataCorrupted(.init(
                codingPath: [],
                debugDescription: "Unparseable calendar date \(raw)"
            ))
        }
    }

    /// The `yyyy-MM-dd` form Home Assistant uses for all-day boundaries, shared by decoding here and
    /// by the create command so the two can't drift apart.
    public static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let fractionalSecondsFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let internetDateTimeFormatter = ISO8601DateFormatter()

    /// Home Assistant emits local date-times with an offset, but integrations occasionally send
    /// fractional seconds or omit the offset entirely, so all three are attempted.
    private static func dateTime(from raw: String) -> Date? {
        if let date = fractionalSecondsFormatter.date(from: raw) { return date }
        if let date = internetDateTimeFormatter.date(from: raw) { return date }
        return offsetlessFormatter.date(from: raw)
    }

    private static let offsetlessFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter
    }()
}
