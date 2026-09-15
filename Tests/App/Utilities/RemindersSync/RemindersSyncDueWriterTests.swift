import EventKit
import Foundation
@testable import HomeAssistant
import Testing

struct RemindersSyncDueWriterTests {
    private let eventStore = EKEventStore()

    private func timed(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> DateComponents {
        DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute, second: 0)
    }

    private func allDay(_ month: Int, _ day: Int) -> DateComponents {
        DateComponents(year: 2026, month: month, day: day)
    }

    private func date(_ components: DateComponents) -> Date {
        Calendar.current.date(from: components) ?? .distantPast
    }

    private func reminder(due: DateComponents?, start: DateComponents? = nil, alarms: [Date] = []) -> EKReminder {
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = "Buy milk"
        reminder.dueDateComponents = due
        reminder.startDateComponents = start
        for alarm in alarms {
            reminder.addAlarm(EKAlarm(absoluteDate: alarm))
        }
        return reminder
    }

    // MARK: - The due date itself

    @Test func testWriteSetsTheDueDate() throws {
        let reminder = reminder(due: timed(7, 17, 10))
        RemindersSyncDueWriter.write(timed(7, 17, 13), to: reminder)
        let written = try #require(reminder.dueDateComponents)
        #expect(date(written) == date(timed(7, 17, 13)))
    }

    @Test func testWriteClearsTheDueDate() {
        let reminder = reminder(due: timed(7, 17, 10))
        RemindersSyncDueWriter.write(nil, to: reminder)
        #expect(reminder.dueDateComponents == nil)
    }

    // MARK: - Alerts anchored to the due date

    @Test func testWriteMovesAnAlertPinnedToTheDueDate() {
        let reminder = reminder(due: timed(7, 17, 10), alarms: [date(timed(7, 17, 10))])
        RemindersSyncDueWriter.write(timed(7, 17, 13), to: reminder)
        #expect(reminder.alarms?.first?.absoluteDate == date(timed(7, 17, 13)))
    }

    @Test func testWriteKeepsAnAlertsDistanceFromTheDueDate() {
        let reminder = reminder(due: timed(7, 17, 10), alarms: [date(timed(7, 17, 9))])
        RemindersSyncDueWriter.write(timed(7, 18, 10), to: reminder)
        #expect(reminder.alarms?.first?.absoluteDate == date(timed(7, 18, 9)))
    }

    @Test func testWriteLeavesRelativeAlertsAloneWhenTheDueDateMoves() {
        let reminder = reminder(due: timed(7, 17, 10))
        reminder.addAlarm(EKAlarm(relativeOffset: -3600))
        RemindersSyncDueWriter.write(timed(7, 17, 13), to: reminder)
        #expect(reminder.alarms?.first?.relativeOffset == -3600)
        #expect(reminder.alarms?.first?.absoluteDate == nil)
    }

    @Test func testWriteRemovesAbsoluteAlertsWhenTheDueDateGoesAway() {
        let reminder = reminder(due: timed(7, 17, 10), alarms: [date(timed(7, 17, 10))])
        RemindersSyncDueWriter.write(nil, to: reminder)
        #expect(reminder.alarms?.isEmpty ?? true)
    }

    @Test func testWriteRemovesRelativeAlertsWhenTheDueDateGoesAway() {
        let reminder = reminder(due: timed(7, 17, 10))
        reminder.addAlarm(EKAlarm(relativeOffset: -3600))
        RemindersSyncDueWriter.write(nil, to: reminder)
        #expect(reminder.alarms?.isEmpty ?? true)
    }

    @Test func testWriteLeavesAlertsAloneWhenTheDueDateDidNotMove() {
        let reminder = reminder(due: timed(7, 17, 10), alarms: [date(timed(7, 17, 10))])
        RemindersSyncDueWriter.write(timed(7, 17, 10), to: reminder)
        #expect(reminder.alarms?.first?.absoluteDate == date(timed(7, 17, 10)))
    }

    @Test func testWriteLeavesAlertsAloneWhenThereWasNoDueDateToAnchorTo() {
        let reminder = reminder(due: nil, alarms: [date(timed(7, 17, 10))])
        RemindersSyncDueWriter.write(timed(7, 20, 10), to: reminder)
        #expect(reminder.alarms?.first?.absoluteDate == date(timed(7, 17, 10)))
    }

    // MARK: - Start dates anchored to the due date

    @Test func testWriteMovesATimedStartDateWithTheDueDate() throws {
        let reminder = reminder(due: timed(7, 17, 10), start: timed(7, 17, 10))
        RemindersSyncDueWriter.write(timed(7, 17, 8), to: reminder)
        let start = try #require(reminder.startDateComponents)
        #expect(date(start) == date(timed(7, 17, 8)))
    }

    @Test func testWriteMovesATimedStartDateAcrossADayBoundary() throws {
        let reminder = reminder(due: timed(7, 17, 23), start: timed(7, 17, 23))
        RemindersSyncDueWriter.write(timed(7, 18, 1), to: reminder)
        let start = try #require(reminder.startDateComponents)
        #expect(date(start) == date(timed(7, 18, 1)))
    }

    @Test func testWriteMovesAnAllDayStartDateByWholeDays() throws {
        let reminder = reminder(due: allDay(7, 17), start: allDay(7, 17))
        RemindersSyncDueWriter.write(allDay(7, 20), to: reminder)
        let start = try #require(reminder.startDateComponents)
        #expect(start.hour == nil)
        #expect(date(start) == date(allDay(7, 20)))
    }

    @Test func testWriteMovesAnAllDayStartDateByWholeDaysAcrossADaylightSavingChange() throws {
        let reminder = reminder(due: allDay(7, 17), start: allDay(10, 24))
        RemindersSyncDueWriter.write(allDay(7, 20), to: reminder)
        let start = try #require(reminder.startDateComponents)
        #expect(date(start) == date(allDay(10, 27)))
    }

    @Test func testWriteLeavesAnAllDayStartDateOnItsDayForASubDayMove() throws {
        let reminder = reminder(due: timed(7, 17, 10), start: allDay(7, 17))
        RemindersSyncDueWriter.write(timed(7, 17, 13), to: reminder)
        let start = try #require(reminder.startDateComponents)
        #expect(date(start) == date(allDay(7, 17)))
    }

    @Test func testWriteClearsTheStartDateWhenTheDueDateGoesAway() {
        let reminder = reminder(due: timed(7, 17, 10), start: timed(7, 17, 10))
        RemindersSyncDueWriter.write(nil, to: reminder)
        #expect(reminder.startDateComponents == nil)
    }
}
