import EventKit
import Foundation
import Shared

/// A normalized, side-agnostic view of one todo item, used to compare the Home Assistant and
/// Apple Reminders copies of an item against each other and against the state stored in
/// `RemindersSyncItemLink` at the last sync.
struct RemindersSyncItemSnapshot: Equatable {
    var title: String
    var isCompleted: Bool
    var notes: String?
    /// Normalized due string: `yyyy-MM-dd` for all-day items, ISO8601 with offset when a time is
    /// set. Both sides are normalized through the same formatter so equal due dates compare equal.
    var due: String?

    var hasDueTime: Bool { due?.contains("T") ?? false }

    /// Value for the todo services' `due_date` field (all-day items only).
    var dueDateArgument: String? { hasDueTime ? nil : due }
    /// Value for the todo services' `due_datetime` field (timed items only).
    var dueDateTimeArgument: String? { hasDueTime ? due : nil }

    init(title: String, isCompleted: Bool, notes: String?, due: String?) {
        self.title = title
        self.isCompleted = isCompleted
        self.notes = notes
        self.due = due
    }

    init(todoItem: TodoListItem) {
        self.title = todoItem.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        self.isCompleted = todoItem.status == "completed"
        self.notes = Self.normalizedNotes(todoItem.description)
        if let raw = todoItem.dueRaw {
            // An uncanonicalized string would never compare equal to the reminder's canonical
            // one and cause an update on every sync.
            if raw.contains("T"), let date = todoItem.due ?? Self.parseDueDateTime(raw) {
                self.due = Self.canonicalDueString(from: date)
            } else {
                self.due = raw
            }
        } else {
            self.due = nil
        }
    }

    init(reminder: EKReminder) {
        self.title = (reminder.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        self.isCompleted = reminder.isCompleted
        self.notes = Self.normalizedNotes(reminder.notes)
        if let components = reminder.dueDateComponents {
            if components.hour != nil, let date = Calendar.current.date(from: components) {
                self.due = Self.canonicalDueString(from: date)
            } else if let year = components.year, let month = components.month, let day = components.day {
                self.due = String(format: "%04d-%02d-%02d", year, month, day)
            } else {
                self.due = nil
            }
        } else {
            self.due = nil
        }
    }

    /// A copy without the fields the todo list can't store, so both sides compare equal on
    /// fields that can never sync (`nil` features, from a failed state fetch, trims nothing).
    /// A timed due is downgraded to its date part when the list only supports date-only dues.
    func trimmed(to features: TodoListEntityFeature?) -> RemindersSyncItemSnapshot {
        guard let features else { return self }
        var copy = self
        if !features.contains(.setDescriptionOnItem) {
            copy.notes = nil
        }
        if let due {
            if hasDueTime, !features.contains(.setDueDatetimeOnItem) {
                copy.due = features.contains(.setDueDateOnItem) ? String(due.prefix(10)) : nil
            } else if !hasDueTime, !features.contains(.setDueDateOnItem) {
                copy.due = nil
            }
        }
        return copy
    }

    /// The due date as `EKReminder.dueDateComponents`.
    var dueComponents: DateComponents? {
        guard let due else { return nil }
        if hasDueTime {
            guard let date = Self.parseDueDateTime(due) else { return nil }
            return Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        } else {
            let parts = due.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 3 else { return nil }
            return DateComponents(year: parts[0], month: parts[1], day: parts[2])
        }
    }

    static func normalizedNotes(_ notes: String?) -> String? {
        guard let trimmed = notes?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    static func canonicalDueString(from date: Date) -> String {
        TodoListItem.canonicalDueString(from: date)
    }

    static func parseDueDateTime(_ string: String) -> Date? {
        TodoListItem.parseDueDateTime(string)
    }
}
