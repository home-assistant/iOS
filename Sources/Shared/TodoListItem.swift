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

        // Parse due date - can be date only (YYYY-MM-DD) or datetime (YYYY-MM-DDTHH:MM:SS+TZ)
        if let dueString = dueRaw {
            if dueString.contains("T") {
                // DateTime format - try ISO8601
                let dateFormatter = ISO8601DateFormatter()
                dateFormatter.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
                // Try with timezone first
                if let date = dateFormatter.date(from: dueString) {
                    self.due = date
                } else {
                    // Try with fractional seconds
                    dateFormatter.formatOptions.insert(.withFractionalSeconds)
                    self.due = dateFormatter.date(from: dueString)
                }
            } else {
                // Date-only format (YYYY-MM-DD)
                let dateOnlyFormatter = DateFormatter()
                dateOnlyFormatter.dateFormat = "yyyy-MM-dd"
                dateOnlyFormatter.timeZone = .current
                self.due = dateOnlyFormatter.date(from: dueString)
            }
        } else {
            self.due = nil
        }
    }

    public init(summary: String, uid: String, status: String, description: String?, dueRaw: String? = nil, due: Date? = nil) {
        self.summary = summary
        self.uid = uid
        self.status = status
        self.description = description
        self.dueRaw = dueRaw
        self.due = due
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
