import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import XCTest

/// Adding an event to a Home Assistant calendar on Siri's behalf.
///
/// `perform()` hands back an opaque `some ReturnsValue<…>`, so the command it sent is what says it
/// did the right thing — the same reasoning as `OpenCloseEntityAppIntentTests`.
@available(iOS 27.0, *)
final class CreateEventSchemaIntentTests: AppIntentSchemaTestCase {
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func intent(calendar: HACalendar) -> CreateEventSchemaIntent {
        let intent = CreateEventSchemaIntent()
        intent.title = "Lunch"
        intent.startDate = start
        intent.calendar = CalendarSchemaEntity(calendar: calendar)
        intent.isAllDay = false
        intent.attendees = []
        return intent
    }

    func testTheEventIsCreatedOnTheNamedCalendar() async throws {
        let calendar = try seedCalendar(entityId: "calendar.home", supportedFeatures: 1)
        let sut = intent(calendar: calendar)
        sut.endDate = start.addingTimeInterval(3600)

        let task = Task { try await sut.perform() }
        let pending = try await request()

        XCTAssertEqual(pending.request.type.command, "calendar/event/create")
        XCTAssertEqual(pending.request.data["entity_id"] as? String, "calendar.home")
        let event = pending.request.data["event"] as? [String: Any]
        XCTAssertEqual(event?["summary"] as? String, "Lunch")

        pending.completion(.success(.dictionary([:])))
        _ = try await task.value
    }

    /// The end the caller left out becomes an hour, matching how the frontend opens a new event.
    func testAMissingEndBecomesAnHour() async throws {
        let sut = try intent(calendar: seedCalendar(supportedFeatures: 1))

        let task = Task { try await sut.perform() }
        let pending = try await request()
        let event = pending.request.data["event"] as? [String: Any]
        let formatter = ISO8601DateFormatter()

        XCTAssertEqual(formatter.date(from: event?["dtstart"] as? String ?? ""), start)
        XCTAssertEqual(
            formatter.date(from: event?["dtend"] as? String ?? ""),
            start.addingTimeInterval(3600)
        )

        pending.completion(.success(.dictionary([:])))
        _ = try await task.value
    }

    /// Home Assistant stores an exclusive end, so an all-day event the user picked for one day is
    /// sent through to the day after.
    func testAnAllDayEventIsSentAsDaysWithAnExclusiveEnd() async throws {
        let sut = try intent(calendar: seedCalendar(supportedFeatures: 1))
        sut.isAllDay = true

        let task = Task { try await sut.perform() }
        let pending = try await request()
        let event = pending.request.data["event"] as? [String: Any]
        let dtstart = try XCTUnwrap(event?["dtstart"] as? String)
        let dtend = try XCTUnwrap(event?["dtend"] as? String)

        XCTAssertEqual(dtstart, HACalendarEvent.dayFormatter.string(from: start))
        XCTAssertEqual(
            dtend,
            try HACalendarEvent.dayFormatter.string(from: XCTUnwrap(Calendar.current.date(
                byAdding: .day,
                value: 1,
                to: start
            )))
        )
        XCTAssertNotEqual(dtstart, dtend)

        pending.completion(.success(.dictionary([:])))
        _ = try await task.value
    }

    func testTheOptionalFieldsAreOnlySentWhenThereIsSomethingToSend() async throws {
        let sut = try intent(calendar: seedCalendar(supportedFeatures: 1))
        sut.note = AttributedString("Table for two")
        sut.location = .text("The Canteen")
        sut.recurrence = Calendar.RecurrenceRule(calendar: .current, frequency: .weekly)

        let task = Task { try await sut.perform() }
        let pending = try await request()
        let event = pending.request.data["event"] as? [String: Any]

        XCTAssertEqual(event?["description"] as? String, "Table for two")
        XCTAssertEqual(event?["location"] as? String, "The Canteen")
        XCTAssertEqual(event?["rrule"] as? String, "FREQ=WEEKLY")

        pending.completion(.success(.dictionary([:])))
        _ = try await task.value
    }

    func testFieldsTheCallerLeftOutAreNotSentAtAll() async throws {
        let sut = try intent(calendar: seedCalendar(supportedFeatures: 1))

        let task = Task { try await sut.perform() }
        let pending = try await request()
        let event = pending.request.data["event"] as? [String: Any]

        XCTAssertNil(event?["description"])
        XCTAssertNil(event?["location"])
        XCTAssertNil(event?["rrule"])

        pending.completion(.success(.dictionary([:])))
        _ = try await task.value
    }

    /// A calendar that cannot take new events rejects the write server-side, so nothing is sent.
    func testACalendarThatCannotAddEventsIsRefusedBeforeAnythingIsSent() async throws {
        let sut = try intent(calendar: seedCalendar(name: "Holidays", supportedFeatures: 2))

        do {
            _ = try await sut.perform()
            XCTFail("expected a calendar without createEvent to be refused")
        } catch {
            XCTAssertEqual(
                (error as? ShortcutAppIntentError)?.errorDescription,
                L10n.AppIntents.Calendar.Error.createUnsupported("Holidays")
            )
        }
        XCTAssertTrue(connection.pendingRequests.isEmpty)
    }

    /// HAKit queues a WebSocket command until the connection is ready and never times it out, so
    /// the command has to give up on its own instead of leaving Siri waiting on a hang.
    func testACommandTheServerNeverAnswersTimesOut() async throws {
        let previousTimeout = HomeAssistantAPI.commandTimeout
        HomeAssistantAPI.commandTimeout = 0.05
        defer { HomeAssistantAPI.commandTimeout = previousTimeout }
        let sut = try intent(calendar: seedCalendar(supportedFeatures: 1))

        do {
            _ = try await sut.perform()
            XCTFail("expected an unanswered command to time out")
        } catch {
            XCTAssertEqual(
                (error as? ShortcutAppIntentError)?.errorDescription,
                L10n.AppIntents.Calendar.Error.timeout
            )
        }
        XCTAssertEqual(connection.cancelledRequests.count, 1)

        // An answer that arrives after the command gave up must not resume it a second time.
        try await request().completion(.success(.dictionary([:])))
    }

    /// A connection that is already ready answers while the command is still being sent, which is
    /// the one moment the command has nothing to cancel yet.
    func testACommandAnsweredAsItIsSentSucceeds() async throws {
        let api = try XCTUnwrap(Current.api(for: server))
        let immediate = ImmediateHAConnection()
        api.connection = immediate
        let sut = try intent(calendar: seedCalendar(supportedFeatures: 1))

        _ = try await sut.perform()

        XCTAssertEqual(immediate.sentCommands, ["calendar/event/create"])
        XCTAssertEqual(immediate.cancellables.first?.wasCancelled, true)
    }

    /// Siri reads `localizedStringResource`, so an error without one is reported as a bare failure.
    func testTheRefusalReachesSiriAsItsOwnMessage() async throws {
        let sut = try intent(calendar: seedCalendar(name: "Holidays", supportedFeatures: 2))

        do {
            _ = try await sut.perform()
            XCTFail("expected a calendar without createEvent to be refused")
        } catch let error as ShortcutAppIntentError {
            XCTAssertEqual(
                String(localized: error.localizedStringResource),
                L10n.AppIntents.Calendar.Error.createUnsupported("Holidays")
            )
        }
    }

    func testAnEventThatEndsBeforeItStartsIsRefused() async throws {
        let sut = try intent(calendar: seedCalendar(supportedFeatures: 1))
        sut.endDate = start.addingTimeInterval(-60)

        do {
            _ = try await sut.perform()
            XCTFail("expected a backwards event to be refused")
        } catch {
            XCTAssertTrue(error is ShortcutAppIntentError)
        }
        XCTAssertTrue(connection.pendingRequests.isEmpty)
    }

    /// Answers every command as it is sent, the way a connection that is already ready does.
    ///
    /// `HAMockConnection` only queues, and it is not open, so the inline answer needs its own
    /// connection rather than a subclass.
    private final class ImmediateHAConnection: HAConnection {
        weak var delegate: HAConnectionDelegate?
        var configuration = HAConnectionConfiguration(
            connectionInfo: { nil },
            fetchAuthToken: { completion in completion(.success("token")) }
        )
        var state: HAConnectionState = .ready(version: "1.0-fake")
        lazy var caches: HACachesContainer = .init(connection: self)
        var callbackQueue: DispatchQueue = .main

        private(set) var sentCommands: [String] = []
        private(set) var cancellables: [HAMockCancellable] = []

        func connect() {}

        func disconnect() {}

        @discardableResult
        func send(_ request: HARequest, completion: @escaping RequestCompletion) -> HACancellable {
            sentCommands.append(request.type.command)
            completion(.success(.dictionary([:])))
            return record()
        }

        @discardableResult
        func send<T: HADataDecodable>(
            _ request: HATypedRequest<T>,
            completion: @escaping (Swift.Result<T, HAError>) -> Void
        ) -> HACancellable {
            sentCommands.append(request.request.type.command)
            do {
                try completion(.success(T(data: .dictionary([:]))))
            } catch {
                completion(.failure(.underlying(error as NSError)))
            }
            return record()
        }

        @discardableResult
        func subscribe(to request: HARequest, handler: @escaping SubscriptionHandler) -> HACancellable {
            record()
        }

        @discardableResult
        func subscribe(
            to request: HARequest,
            initiated: @escaping SubscriptionInitiatedHandler,
            handler: @escaping SubscriptionHandler
        ) -> HACancellable {
            record()
        }

        @discardableResult
        func subscribe<T>(
            to request: HATypedSubscription<T>,
            handler: @escaping (HACancellable, T) -> Void
        ) -> HACancellable {
            record()
        }

        @discardableResult
        func subscribe<T>(
            to request: HATypedSubscription<T>,
            initiated: @escaping SubscriptionInitiatedHandler,
            handler: @escaping (HACancellable, T) -> Void
        ) -> HACancellable {
            record()
        }

        private func record() -> HAMockCancellable {
            let cancellable = HAMockCancellable {}
            cancellables.append(cancellable)
            return cancellable
        }
    }

    /// The command returns nothing, so the calendar is read back once the server has accepted the
    /// event and not before: that is what puts the new event, uid included, where Siri reads from.
    func testTheCalendarIsReadBackOnceTheEventIsCreated() async throws {
        let calendar = try seedCalendar(supportedFeatures: 1)
        let sut = intent(calendar: calendar)

        let task = Task { try await sut.perform() }
        let pending = try await request()
        XCTAssertTrue(calendarsModel.eventsRequests.isEmpty)

        pending.completion(.success(.dictionary([:])))
        _ = try await task.value

        let readBack = try XCTUnwrap(calendarsModel.eventsRequests.first)
        XCTAssertEqual(calendarsModel.refreshedCalendars.map(\.id), [calendar.id])
        XCTAssertTrue(readBack.covers(start))
    }

    func testARefusedEventLeavesTheCacheAlone() async throws {
        let sut = try intent(calendar: seedCalendar(supportedFeatures: 2))

        _ = try? await sut.perform()

        XCTAssertTrue(calendarsModel.eventsRequests.isEmpty)
    }

    /// Once the read-back finds the event the server stored, that is what Siri is handed back, uid
    /// included, rather than a description of what was asked for.
    func testTheStoredEventIsHandedBackWhenTheReadBackFindsIt() async throws {
        let calendar = try seedCalendar(supportedFeatures: 1)
        calendarsModel.serverReturns([
            HACalendarEventRecord(
                id: "stored",
                serverId: serverId,
                calendarEntityId: calendar.entityId,
                uid: "uid-stored",
                recurrenceId: nil,
                summary: "Lunch",
                start: start,
                end: start.addingTimeInterval(3600),
                isAllDay: false,
                eventDescription: nil,
                location: nil,
                rrule: nil
            ),
        ], for: calendar)
        let sut = intent(calendar: calendar)

        let task = Task { try await sut.perform() }
        try await acknowledge()
        _ = try await task.value

        let stored = await CalendarSchemaSupport.cachedEvent(
            on: calendar,
            titled: "Lunch",
            start: start,
            end: start.addingTimeInterval(3600),
            isAllDay: false
        )
        XCTAssertEqual(stored?.uid, "uid-stored")
    }
}
