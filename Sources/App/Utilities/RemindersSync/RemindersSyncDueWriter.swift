import EventKit
import Foundation

/// Writes a due date onto a reminder together with the dates anchored to it. A reminder created
/// in the Apple Reminders app carries an alert, and often a start date, pinned to its due date;
/// moving the due date on its own leaves those behind, so the reminder keeps alerting at the old
/// time and a start date later than the new due makes EventKit reject the save.
enum RemindersSyncDueWriter {
    static func write(_ due: DateComponents?, to reminder: EKReminder) {
        let previousDue = reminder.dueDateComponents
        reminder.dueDateComponents = due

        guard due != nil else {
            reminder.startDateComponents = nil
            for alarm in reminder.alarms ?? [] {
                reminder.removeAlarm(alarm)
            }
            return
        }
        guard let move = Move(from: previousDue, to: due) else { return }

        if let startDateComponents = reminder.startDateComponents {
            reminder.startDateComponents = move.applied(to: startDateComponents)
        }
        for alarm in reminder.alarms ?? [] {
            if let absoluteDate = alarm.absoluteDate {
                alarm.absoluteDate = absoluteDate.addingTimeInterval(move.seconds)
            }
        }
    }

    private struct Move {
        let seconds: TimeInterval
        let days: Int

        init?(from previous: DateComponents?, to new: DateComponents?) {
            let calendar = Calendar.current
            guard let previous, let new,
                  let previousDate = calendar.date(from: previous),
                  let newDate = calendar.date(from: new) else { return nil }
            let seconds = newDate.timeIntervalSince(previousDate)
            guard seconds != 0 else { return nil }
            self.seconds = seconds
            self.days = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: previousDate),
                to: calendar.startOfDay(for: newDate)
            ).day ?? 0
        }

        /// Timed values follow the due date by the elapsed time between the two; a date-only value
        /// is a calendar day rather than an instant, so it follows by whole local days instead and
        /// can't land on the wrong one when a daylight saving change falls between them.
        func applied(to components: DateComponents) -> DateComponents {
            let calendar = Calendar.current
            guard let date = calendar.date(from: components) else { return components }
            guard components.hour != nil else {
                let moved = calendar.date(byAdding: .day, value: days, to: date) ?? date
                return calendar.dateComponents([.year, .month, .day], from: moved)
            }
            return calendar.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: date.addingTimeInterval(seconds)
            )
        }
    }
}
