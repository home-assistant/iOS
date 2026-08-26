import Foundation
import HAKit

public struct TodoListItem: HADataDecodable {
    public let summary: String
    public let uid: String
    public let status: String
    public let description: String?
    /// Raw due string from API - can be "YYYY-MM-DD" or "YYYY-MM-DDTHH:MM:SS"
    public let dueRaw: String?
    /// Parsed due date
    public let due: Date?
    /// Whether the due field includes time (contains "T")
    public var hasDueTime: Bool {
        dueRaw?.contains("T") ?? false
    }

    public init(data: HAData) throws {
        self.summary = try data.decode("summary")
        self.uid = try data.decode("uid")
        self.status = try data.decode("status")
        self.description = try? data.decode("description") as String?
        self.dueRaw = try? data.decode("due") as String?

        if let dueString = dueRaw {
            self.due = dueString.contains("T")
                ? Self.parseDueDateTime(dueString)
                : Self.parseDueDate(dueString)
        } else {
            self.due = nil
        }
    }

    public init(
        summary: String,
        uid: String,
        status: String,
        description: String?,
        dueRaw: String? = nil,
        due: Date? = nil
    ) {
        self.summary = summary
        self.uid = uid
        self.status = status
        self.description = description
        self.dueRaw = dueRaw
        self.due = due
    }

    /// Parses a `yyyy-MM-dd` due value into midnight in the current timezone.
    public static func parseDueDate(_ string: String) -> Date? {
        DueDateFormatters.current.localDate.date(from: string)
    }

    /// Parses a due datetime, honouring the UTC offset the server sends. A value without an
    /// offset is a naive local wall clock time and is interpreted in the current timezone.
    public static func parseDueDateTime(_ string: String) -> Date? {
        let formatters = DueDateFormatters.current
        if let date = formatters.internetDateTime.date(from: string) {
            return date
        }
        if let date = formatters.fractionalInternetDateTime.date(from: string) {
            return date
        }
        return formatters.localDateTime.date(from: string)
    }

    /// The canonical `due_datetime` representation: ISO8601 in the current timezone, offset
    /// included, so the server can never mistake it for a naive local time.
    public static func canonicalDueString(from date: Date) -> String {
        DueDateFormatters.current.internetDateTime.string(from: date)
    }

    /// Formatted due date string for display
    public var formattedDue: String? {
        guard let due else { return nil }

        let formatter = DateFormatter()
        if hasDueTime {
            formatter.dateStyle = .short
            formatter.timeStyle = .short
        } else {
            formatter.dateStyle = .short
            formatter.timeStyle = .none
        }
        return formatter.string(from: due)
    }

    private final class DueDateFormatters {
        let timeZone: TimeZone
        let internetDateTime: ISO8601DateFormatter
        let fractionalInternetDateTime: ISO8601DateFormatter
        let localDateTime: DateFormatter
        let localDate: DateFormatter

        private static let lock = NSLock()
        private static var cached = DueDateFormatters(timeZone: .current)

        static var current: DueDateFormatters {
            let timeZone = TimeZone.current
            lock.lock()
            defer { lock.unlock() }
            if cached.timeZone != timeZone {
                cached = DueDateFormatters(timeZone: timeZone)
            }
            return cached
        }

        init(timeZone: TimeZone) {
            self.timeZone = timeZone
            let internetDateTime = ISO8601DateFormatter()
            internetDateTime.formatOptions = [.withInternetDateTime]
            internetDateTime.timeZone = timeZone
            self.internetDateTime = internetDateTime

            let fractionalInternetDateTime = ISO8601DateFormatter()
            fractionalInternetDateTime.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            fractionalInternetDateTime.timeZone = timeZone
            self.fractionalInternetDateTime = fractionalInternetDateTime

            self.localDateTime = Self.fixedFormatter(format: "yyyy-MM-dd'T'HH:mm:ss", timeZone: timeZone)
            self.localDate = Self.fixedFormatter(format: "yyyy-MM-dd", timeZone: timeZone)
        }

        private static func fixedFormatter(format: String, timeZone: TimeZone) -> DateFormatter {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = timeZone
            formatter.dateFormat = format
            return formatter
        }
    }
}

public struct TodoListService: HADataDecodable {
    public let items: [TodoListItem]

    public init(data: HAData) throws {
        self.items = try data.decode("items")
    }
}

public struct TodoListRawResponse: HADataDecodable {
    public let changedStates: [String]
    public let serviceResponse: [String: TodoListService]

    public init(data: HAData) throws {
        self.changedStates = try data.decode("changed_states")
        self.serviceResponse = try data.decode("service_response")
    }
}
