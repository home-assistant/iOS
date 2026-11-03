import AppIntents
import Foundation
import HAKit
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import Testing

/// Creates, deletes and lists calendar events through the Shortcuts intents, against a mock websocket
/// and a scripted calendars model.
/// Shared state: the intents read `Current.servers`, the database, the API cache and the calendars
/// model.
@Suite(.sharedState)
@MainActor
struct CalendarEventAppIntentsTests {
    // MARK: - Create

    @Test func createsATimedEventForEveryRepeatPreset() async throws {
        guard #available(iOS 17.0, *) else { return }
        for repeating in CalendarEventRepeatAppEnum.allCases {
            try await createsATimedEvent(repeating: repeating)
        }
    }

    @available(iOS 17.0, *)
    private func createsATimedEvent(repeating: CalendarEventRepeatAppEnum) async throws {
        let world = try CalendarTestWorld()
        try await world.run {
            let intent = CreateCalendarEventAppIntent()
            intent.calendar = HACalendarAppEntity(calendar: world.writable)
            intent.summary = "Dentist"
            intent.isAllDay = false
            intent.startDate = Date(timeIntervalSince1970: 1_800_000_000)
            intent.endDate = nil
            intent.repeatFrequency = repeating
            intent.eventDescription = "Checkup"
            intent.location = "Clinic"

            async let result = intent.perform()
            let request = await world.answerNextCommand()
            _ = try await result
            #expect(request?.type == "calendar/event/create")
            let event = request?.data["event"] as? [String: Any]
            #expect(event?["summary"] as? String == "Dentist")
            #expect(event?["location"] as? String == "Clinic")
            #expect((event?["rrule"] as? String != nil) == (repeating != .none))
        }
    }

    @Test func createsAnAllDayEventWithDefaults() async throws {
        guard #available(iOS 17.0, *) else { return }
        let world = try CalendarTestWorld()
        try await world.run {
            let intent = CreateCalendarEventAppIntent()
            intent.calendar = HACalendarAppEntity(calendar: world.writable)
            intent.summary = "Holiday"
            intent.isAllDay = true
            intent.startDate = nil
            intent.endDate = nil
            intent.repeatFrequency = .none
            intent.eventDescription = nil
            intent.location = nil

            async let result = intent.perform()
            let request = await world.answerNextCommand()
            _ = try await result
            let event = request?.data["event"] as? [String: Any]
            #expect((event?["dtstart"] as? String)?.count == 10)
        }
    }

    @Test func refusesInvalidCreates() async throws {
        guard #available(iOS 17.0, *) else { return }
        let world = try CalendarTestWorld()
        try await world.run {
            func intent(
                _ calendar: HACalendar,
                allDay: Bool,
                start: Date?,
                end: Date?
            ) -> CreateCalendarEventAppIntent {
                let intent = CreateCalendarEventAppIntent()
                intent.calendar = HACalendarAppEntity(calendar: calendar)
                intent.summary = "Nope"
                intent.isAllDay = allDay
                intent.startDate = start
                intent.endDate = end
                intent.repeatFrequency = .none
                intent.eventDescription = nil
                intent.location = nil
                return intent
            }
            let now = Date(timeIntervalSince1970: 1_800_000_000)
            let unknown = world.calendar(entityId: "calendar.gone", name: "Gone", features: 7)
            await #expect(throws: (any Error).self) {
                _ = try await intent(unknown, allDay: false, start: nil, end: nil).perform()
            }
            await #expect(throws: (any Error).self) {
                _ = try await intent(world.readOnly, allDay: false, start: nil, end: nil).perform()
            }
            await #expect(throws: (any Error).self) {
                _ = try await intent(world.writable, allDay: false, start: now, end: now).perform()
            }
            await #expect(throws: (any Error).self) {
                _ = try await intent(world.writable, allDay: true, start: now, end: now.addingTimeInterval(-86400))
                    .perform()
            }
            #expect(world.connection.pendingRequests.isEmpty)
        }
    }

    /// The Shortcuts editor's summaries, and both write intents refusing a calendar whose server
    /// is gone.
    @Test func summariesAndCalendarsWithoutAServer() async throws {
        guard #available(iOS 17.0, *) else { return }
        _ = CreateCalendarEventAppIntent.parameterSummary
        _ = DeleteCalendarEventAppIntent.parameterSummary
        _ = GetCalendarEventsAppIntent.parameterSummary

        let world = try CalendarTestWorld()
        try await world.run {
            Current.servers = FakeServerManager(initial: 0)
            let now = Date(timeIntervalSince1970: 1_800_000_000)

            let create = CreateCalendarEventAppIntent()
            create.calendar = HACalendarAppEntity(calendar: world.writable)
            create.summary = "Orphan"
            create.isAllDay = false
            create.startDate = now
            create.endDate = now.addingTimeInterval(3600)
            create.repeatFrequency = .none
            create.eventDescription = nil
            create.location = nil
            await #expect(throws: (any Error).self) { _ = try await create.perform() }

            let delete = DeleteCalendarEventAppIntent()
            delete.calendar = HACalendarAppEntity(calendar: world.writable)
            delete.event = try #require(HACalendarEventAppEntity(payload: payload(world.writable, uid: "abc")))
            delete.scope = .thisEvent
            await #expect(throws: (any Error).self) { _ = try await delete.perform() }
            #expect(world.connection.pendingRequests.isEmpty)
        }
    }

    // MARK: - Delete

    @Test func deletesARecurringOccurrenceInEveryScope() async throws {
        guard #available(iOS 17.0, *) else { return }
        for scope in CalendarEventDeleteScopeAppEnum.allCases {
            try await deletesARecurringOccurrence(scope: scope)
        }
    }

    @available(iOS 17.0, *)
    private func deletesARecurringOccurrence(scope: CalendarEventDeleteScopeAppEnum) async throws {
        let world = try CalendarTestWorld()
        try await world.run {
            let intent = DeleteCalendarEventAppIntent()
            intent.calendar = HACalendarAppEntity(calendar: world.writable)
            intent.event = try #require(HACalendarEventAppEntity(payload: payload(world.writable, uid: "abc")))
            intent.scope = scope

            async let result = intent.perform()
            let request = await world.answerNextCommand()
            _ = try await result
            #expect(request?.type == "calendar/event/delete")
            #expect(request?.data["uid"] as? String == "abc")
            #expect((request?.data["recurrence_range"] != nil) == (scope == .thisAndFuture))
        }
    }

    @Test func refusesInvalidDeletes() async throws {
        guard #available(iOS 17.0, *) else { return }
        let world = try CalendarTestWorld()
        try await world.run {
            func intent(_ calendar: HACalendar, event: HACalendar, uid: String?) throws
                -> DeleteCalendarEventAppIntent {
                let intent = DeleteCalendarEventAppIntent()
                intent.calendar = HACalendarAppEntity(calendar: calendar)
                intent.event = try #require(HACalendarEventAppEntity(payload: payload(event, uid: uid)))
                intent.scope = .thisEvent
                return intent
            }
            let unknown = world.calendar(entityId: "calendar.gone", name: "Gone", features: 7)
            for sut in try [
                intent(unknown, event: unknown, uid: "a"),
                intent(world.writable, event: world.readOnly, uid: "a"),
                intent(world.readOnly, event: world.readOnly, uid: "a"),
                intent(world.writable, event: world.writable, uid: nil),
            ] {
                await #expect(throws: (any Error).self) { _ = try await sut.perform() }
            }
        }
    }

    // MARK: - Get

    @Test func listsEventsAsEntities() async throws {
        guard #available(iOS 17.0, *) else { return }
        let world = try CalendarTestWorld()
        world.model.events = [
            HACalendarEvent(summary: "One", start: Date(), end: Date().addingTimeInterval(60), isAllDay: false),
            HACalendarEvent(
                summary: "Two",
                start: Date(),
                end: Date().addingTimeInterval(86400),
                isAllDay: true,
                uid: "two",
                recurrenceId: "r",
                rrule: "FREQ=DAILY"
            ),
        ]
        try await world.run {
            let intent = GetCalendarEventsAppIntent()
            intent.calendar = HACalendarAppEntity(calendar: world.writable)
            intent.startDate = Date()
            intent.endDate = Date().addingTimeInterval(86400)
            let result = try await intent.perform()
            let entities = try #require(result.value)
            #expect(entities.map(\.payload.summary) == ["One", "Two"])
            #expect(entities[1].payload.isRecurring)
            for entity in entities {
                #expect(!String(localized: entity.displayRepresentation.title).isEmpty)
                #expect(HACalendarEventAppEntity(id: entity.id)?.payload == entity.payload)
            }

            let backwards = GetCalendarEventsAppIntent()
            backwards.calendar = HACalendarAppEntity(calendar: world.writable)
            backwards.startDate = Date()
            backwards.endDate = Date().addingTimeInterval(-60)
            await #expect(throws: (any Error).self) { _ = try await backwards.perform() }

            let unknown = GetCalendarEventsAppIntent()
            unknown.calendar = HACalendarAppEntity(calendar: world.calendar(
                entityId: "calendar.gone",
                name: "Gone",
                features: 0
            ))
            unknown.startDate = Date()
            unknown.endDate = Date()
            await #expect(throws: (any Error).self) { _ = try await unknown.perform() }
        }
    }

    // MARK: - Repeat presets

    @Test func repeatPresetsProduceRRules() {
        guard #available(iOS 17.0, *) else { return }
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(CalendarEventRepeatAppEnum.none.rrule(startingOn: start) == nil)
        #expect(CalendarEventRepeatAppEnum.yearly.rrule(startingOn: start) == "FREQ=YEARLY")
        #expect(CalendarEventRepeatAppEnum.monthly.rrule(startingOn: start)?.hasPrefix("FREQ=MONTHLY") == true)
        #expect(CalendarEventRepeatAppEnum.weekly.rrule(startingOn: start)?.hasPrefix("FREQ=WEEKLY") == true)
        #expect(CalendarEventRepeatAppEnum.daily.rrule(startingOn: start) == "FREQ=DAILY")
        #expect(
            CalendarEventRepeatAppEnum.caseDisplayRepresentations.count == CalendarEventRepeatAppEnum.allCases
                .count
        )
        #expect(CalendarEventDeleteScopeAppEnum.thisEvent.recurrenceRange.isEmpty)
    }

    @available(iOS 17.0, *)
    private nonisolated func payload(_ calendar: HACalendar, uid: String?) -> HACalendarEventAppEntity.Payload {
        .init(
            serverId: calendar.serverId,
            calendarEntityId: calendar.entityId,
            calendarName: calendar.name,
            uid: uid,
            recurrenceId: "20261030",
            summary: "Standup",
            start: 1_800_000_000,
            isAllDay: false,
            isRecurring: true
        )
    }
}
