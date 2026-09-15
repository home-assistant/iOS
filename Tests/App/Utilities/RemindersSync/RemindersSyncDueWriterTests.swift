import EventKit
import Foundation
@testable import HomeAssistant
import Testing

struct RemindersSyncDueWriterTests {
    private let eventStore = EKEventStore()

    private func timed(_ day: Int, _ hour: Int, _ minute: Int = 0) -> DateComponents {
        DateComponents(year: 2026, month: 7, day: day, hour: hour, minute: minute, second: 0)
    }

    private func allDay(_ day: Int) -> DateComponents {
        DateComponents(year: 2026, month: 7, day: day)
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

    // MARK: - Writing the due date

    @Test func testWriteSetsTheDueDate() throws {
        let reminder = reminder(due: timed(17, 10))
        RemindersSyncDueWriter.write(timed(17, 13), to: reminder)
        let written = try #require(reminder.dueDateComponents)
        #expect(date(written) == date(timed(17, 13)))
    }

    @Test func testWriteClearsTheDueDate() {
        let reminder = reminder(due: timed(17, 10))
        RemindersSyncDueWriter.write(nil, to: reminder)
        #expect(reminder.dueDateComponents == nil)
    }

    // MARK: - Alerts anchored to the due date

    @Test func testWriteMovesAnAlertPinnedToTheDueDate() {
        let reminder = reminder(due: timed(17, 10), alarms: [date(timed(17, 10))])
        RemindersSyncDueWriter.write(timed(17, 13), to: reminder)
        #expect(reminder.alarms?.first?.absoluteDate == date(timed(17, 13)))
    }

    @Test func testWriteKeepsAnAlertsDistanceFromTheDueDate() {
        let reminder = reminder(due: timed(17, 10), alarms: [date(timed(17, 9))])
        RemindersSyncDueWriter.write(timed(18, 10), to: reminder)
        #expect(reminder.alarms?.first?.absoluteDate == date(timed(18, 9)))
    }

    @Test func testWriteLeavesRelativeAlertsAlone() {
        let reminder = reminder(due: timed(17, 10))
        reminder.addAlarm(EKAlarm(relativeOffset: -3600))
        RemindersSyncDueWriter.write(timed(17, 13), to: reminder)
        #expect(reminder.alarms?.first?.relativeOffset == -3600)
        #expect(reminder.alarms?.first?.absoluteDate == nil)
    }

    @Test func testWriteRemovesAbsoluteAlertsWhenTheDueDateGoesAway() {
        let reminder = reminder(due: timed(17, 10), alarms: [date(timed(17, 10))])
        RemindersSyncDueWriter.write(nil, to: reminder)
        #expect(reminder.alarms?.isEmpty ?? true)
    }

    @Test func testWriteLeavesAlertsAloneWhenTheDueDateDidNotMove() {
        let reminder = reminder(due: timed(17, 10), alarms: [date(timed(17, 10))])
        RemindersSyncDueWriter.write(timed(17, 10), to: reminder)
        #expect(reminder.alarms?.first?.absoluteDate == date(timed(17, 10)))
    }

    @Test func testWriteLeavesAlertsAloneWhenThereWasNoDueDateToAnchorTo() {
        let reminder = reminder(due: nil, alarms: [date(timed(17, 10))])
        RemindersSyncDueWriter.write(timed(20, 10), to: reminder)
        #expect(reminder.alarms?.first?.absoluteDate == date(timed(17, 10)))
    }

    // MARK: - Start dates anchored to the due date

    @Test func testWriteMovesTheStartDateWithTheDueDate() throws {
        let reminder = reminder(due: timed(17, 10), start: timed(17, 10))
        RemindersSyncDueWriter.write(timed(17, 8), to: reminder)
        let start = try #require(reminder.startDateComponents)
        #expect(date(start) == date(timed(17, 8)))
    }

    @Test func testWriteKeepsAnAllDayStartDateAllDay() throws {
        let reminder = reminder(due: allDay(17), start: allDay(17))
        RemindersSyncDueWriter.write(allDay(20), to: reminder)
        let start = try #require(reminder.startDateComponents)
        #expect(start.hour == nil)
        #expect(date(start) == date(allDay(20)))
    }

    @Test func testWriteClearsTheStartDateWhenTheDueDateGoesAway() {
        let reminder = reminder(due: timed(17, 10), start: timed(17, 10))
        RemindersSyncDueWriter.write(nil, to: reminder)
        #expect(reminder.startDateComponents == nil)
    }

    // MARK: - Offset

    @Test func testOffsetIsNilWithoutBothDueDates() {
        #expect(RemindersSyncDueWriter.offset(from: nil, to: timed(17, 10)) == nil)
        #expect(RemindersSyncDueWriter.offset(from: timed(17, 10), to: nil) == nil)
    }

    @Test func testOffsetIsNilWhenTheDueDateDidNotMove() {
        #expect(RemindersSyncDueWriter.offset(from: timed(17, 10), to: timed(17, 10)) == nil)
    }

    @Test func testOffsetMeasuresAForwardAndBackwardMove() {
        #expect(RemindersSyncDueWriter.offset(from: timed(17, 10), to: timed(17, 13, 30)) == 12600)
        #expect(RemindersSyncDueWriter.offset(from: timed(17, 10), to: timed(16, 10)) == -86400)
    }

    // MARK: - Shifting components

    @Test func testShiftedCrossesADayBoundary() throws {
        let shifted = try #require(RemindersSyncDueWriter.shifted(timed(17, 23), by: 7200))
        #expect(date(shifted) == date(timed(18, 1)))
    }

    @Test func testShiftedKeepsAnAllDayValueOnItsDayForASubDayOffset() throws {
        let shifted = try #require(RemindersSyncDueWriter.shifted(allDay(17), by: 12600))
        #expect(date(shifted) == date(allDay(17)))
    }
}
