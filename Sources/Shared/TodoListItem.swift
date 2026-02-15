import Foundation
import HAKit

public struct TodoListItem: HADataDecodable {
    public let summary: String
    public let uid: String
    public let status: String
    public let description: String?
    public let due: Date?
    public let hasDueTime: Bool

    public init(data: HAData) throws {
        self.summary = try data.decode("summary")
        self.uid = try data.decode("uid")
        self.status = try data.decode("status")
        self.description = try? data.decode("description") as String?

        // Parse due date - can be date only (YYYY-MM-DD) or datetime (YYYY-MM-DDTHH:MM:SS)
        if let dueString: String = try? data.decode("due") {
            let dateFormatter = ISO8601DateFormatter()
            dateFormatter.formatOptions = [.withFullDate, .withTime, .withDashSeparatorInDate, .withColonSeparatorInTime]

            if let dateTime = dateFormatter.date(from: dueString) {
                self.due = dateTime
                self.hasDueTime = true
            } else {
                // Try date-only format
                let dateOnlyFormatter = DateFormatter()
                dateOnlyFormatter.dateFormat = "yyyy-MM-dd"
                self.due = dateOnlyFormatter.date(from: dueString)
                self.hasDueTime = false
            }
        } else {
            self.due = nil
            self.hasDueTime = false
        }
    }

    public init(summary: String, uid: String, status: String, description: String?, due: Date? = nil, hasDueTime: Bool = false) {
        self.summary = summary
        self.uid = uid
        self.status = status
        self.description = description
        self.due = due
        self.hasDueTime = hasDueTime
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
