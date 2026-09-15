import EventKit
import Foundation

/// Writes a due date onto a reminder together with the dates anchored to it. A reminder created
/// in the Apple Reminders app carries an alert, and often a start date, pinned to its due date;
/// moving the due date on its own leaves those behind, so the reminder keeps alerting at the old
/// time and a start date later than the new due makes EventKit reject the save outright.
enum RemindersSyncDueWriter {
    static func write(_ due: DateComponents?, to reminder: EKReminder) {
        let offset = offset(from: reminder.dueDateComponents, to: due)
        reminder.dueDateComponents = due

        guard due != nil else {
            reminder.startDateComponents = nil
            for alarm in reminder.alarms ?? [] where alarm.absoluteDate != nil {
                reminder.removeAlarm(alarm)
            }
            return
        }
        guard let offset else { return }

        if let startDateComponents = reminder.startDateComponents {
            reminder.startDateComponents = shifted(startDateComponents, by: offset) ?? startDateComponents
        }
        for alarm in reminder.alarms ?? [] {
            if let absoluteDate = alarm.absoluteDate {
                alarm.absoluteDate = absoluteDate.addingTimeInterval(offset)
            }
        }
    }

    static func offset(from previous: DateComponents?, to new: DateComponents?) -> TimeInterval? {
        let calendar = Calendar.current
        guard let previous, let new,
              let previousDate = calendar.date(from: previous),
              let newDate = calendar.date(from: new) else { return nil }
        let offset = newDate.timeIntervalSince(previousDate)
        return offset == 0 ? nil : offset
    }

    static func shifted(_ components: DateComponents, by offset: TimeInterval) -> DateComponents? {
        let calendar = Calendar.current
        guard let date = calendar.date(from: components) else { return nil }
        let fields: Set<Calendar.Component> = components.hour == nil
            ? [.year, .month, .day]
            : [.year, .month, .day, .hour, .minute, .second]
        return calendar.dateComponents(fields, from: date.addingTimeInterval(offset))
    }
}
