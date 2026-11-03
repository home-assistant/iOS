import EventKit
import Foundation
import GRDB
import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import Testing

/// Applies sync plans without touching the Reminders database: a Reminders → Home Assistant pass
/// runs every todo-side operation against a mocked connection and records the links, the history
/// lines describe each kind of operation, and copying an item onto an `EKReminder` respects what
/// the todo list can store. The manager's entry points are exercised without Reminders access.
///
/// `.sharedState`: the manager moves its database work to detached tasks, which read the global
/// `Current.database`, so that is swapped globally. Every test uses a manager of its own, never the
/// app's `shared` one.
@Suite(.sharedState)
@MainActor
struct RemindersSyncManagerTests {
    private static let listId = "todo.shopping"
    private let eventStore = EKEventStore()

    private func config(_ direction: RemindersSyncDirection) -> RemindersSyncConfig {
        RemindersSyncConfig(
            id: "config",
            serverId: "server",
            todoEntityId: Self.listId,
            todoEntityName: "Shopping",
            reminderListId: "list",
            reminderListName: "Groceries",
            direction: direction
        )
    }

    private func reminder(_ title: String, completed: Bool = false) -> EKReminder {
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.isCompleted = completed
        return reminder
    }

    private func snapshot(_ title: String, completed: Bool = false) -> RemindersSyncItemSnapshot {
        RemindersSyncItemSnapshot(title: title, isCompleted: completed, notes: nil, due: nil)
    }

    private func link(_ uid: String, _ reminderId: String, _ title: String) -> RemindersSyncPlanner.LinkState {
        RemindersSyncPlanner.LinkState(todoItemUid: uid, reminderId: reminderId, snapshot: snapshot(title))
    }

    /// Answers every request the connection receives until `body` returns: the list fetch with
    /// `items`, everything else with an empty success.
    private func answering<T>(
        _ connection: HAMockConnection,
        items: [[String: Any]],
        _ body: @escaping () async throws -> T
    ) async throws -> (T, [HARequest]) {
        let answered = AnsweredRequests()
        let responder = Task { @MainActor in
            while !Task.isCancelled {
                // Take only what was read: the mock appends from whichever thread sends, so a request
                // arriving between the read and a `removeAll()` would be dropped and never answered.
                let pending = connection.pendingRequests
                connection.pendingRequests.removeFirst(pending.count)
                for request in pending {
                    answered.requests.append(request.request)
                    if "\(request.request.type)".contains("get_items") {
                        request.completion(.success(HAData(value: [
                            "changed_states": [Any](),
                            "service_response": [Self.listId: ["items": items]],
                        ])))
                    } else {
                        request.completion(.success(.empty))
                    }
                }
                try? await Task.sleep(nanoseconds: 5_000_000)
            }
        }
        defer { responder.cancel() }
        // Bounded, so a request nobody answers fails the test instead of holding the run until the
        // time limit: the sync awaits its requests on continuations that cancellation does not resume.
        let outcome = Outcome<T>()
        Task { @MainActor in
            do {
                outcome.result = await try .success(body())
            } catch {
                outcome.result = .failure(error)
            }
        }
        let deadline = Date().addingTimeInterval(30)
        while outcome.result == nil, Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        let result = try #require(outcome.result, "The sync did not finish within 30 seconds")
        return try (result.get(), answered.requests)
    }

    private final class Outcome<Value>: @unchecked Sendable {
        private let lock = NSLock()
        private var stored: Result<Value, Error>?

        var result: Result<Value, Error>? {
            get { lock.withLock { stored } }
            set { lock.withLock { stored = newValue } }
        }
    }

    @MainActor
    private final class AnsweredRequests {
        var requests: [HARequest] = []
    }

    @Test func mirroringRemindersRunsEveryTodoOperation() async throws {
        let server = Server.fake()
        let connection = HAMockConnection()
        let api = HomeAssistantAPI(server: server)
        api.connection = connection

        try await SettingsTestDatabase.with { database in
            let remindersById = [
                "r-milk": reminder("Milk"),
                "r-bread": reminder("Bread"),
                "r-eggs": reminder("Eggs"),
                "r-restored": reminder("Restored"),
                "r-done": reminder("Done", completed: true),
            ]
            let (details, requests) = try await answering(connection, items: [
                ["summary": "Milk", "uid": "new-milk", "status": "needs_action"],
                ["summary": "Restored", "uid": "new-restored", "status": "needs_action"],
                ["summary": "Eggs", "uid": "u-eggs", "status": "needs_action"],
            ]) {
                try await RemindersSyncManager().applyPlan(
                    config: config(.toHomeAssistant),
                    api: api,
                    calendar: EKCalendar(for: .reminder, eventStore: eventStore),
                    features: nil,
                    todoSnapshots: [
                        "u-bread": snapshot("Bread old"),
                        "u-gone": snapshot("Gone reminder"),
                        "u-eggs": snapshot("Eggs"),
                    ],
                    remindersById: remindersById,
                    links: [
                        link("u-bread", "r-bread", "Bread old"),
                        link("u-gone", "r-gone", "Gone reminder"),
                        link("u-both-gone", "r-both-gone", "Both gone"),
                        link("u-restored", "r-restored", "Restored"),
                        link("u-done", "r-done", "Done"),
                    ]
                )
            }

            #expect(Set(details) == [
                L10n.RemindersSync.History.Detail.updatedItem("Bread"),
                L10n.RemindersSync.History.Detail.deletedItem("Gone reminder"),
                L10n.RemindersSync.History.Detail.createdItem("Restored"),
                L10n.RemindersSync.History.Detail.createdItem("Milk"),
            ])
            // Update, remove, two adds and the re-fetch that links the new items.
            #expect(requests.count == 5)

            let links = try await database.read { db in
                try RemindersSyncItemLink.fetchAll(db)
            }
            let pairs = Dictionary(uniqueKeysWithValues: links.map { ($0.todoItemUid, $0.reminderId) })
            #expect(pairs == [
                "u-bread": "r-bread",
                "u-eggs": "r-eggs",
                "new-milk": "r-milk",
                "new-restored": "r-restored",
            ])
        }
    }

    /// An event store that refuses every write the way EventKit does without Reminders access,
    /// whatever access the simulator or device running the tests has.
    private final class RefusingEventStore: EKEventStore {
        struct Refusal: Error, Equatable {
            let operation: String
        }

        override func save(_ reminder: EKReminder, commit: Bool) throws {
            throw Refusal(operation: "save")
        }

        override func remove(_ reminder: EKReminder, commit: Bool) throws {
            throw Refusal(operation: "remove")
        }

        override func commit() throws {
            throw Refusal(operation: "commit")
        }
    }

    /// Every write to the Reminders side that the store refuses is reported; the plan still reaches
    /// each write (copying the item onto the reminder first), and a deleted item's link goes first.
    @Test func refusedReminderWritesAreReported() async throws {
        let store = RefusingEventStore()
        let manager = RemindersSyncManager(eventStore: store)
        let connection = HAMockConnection()
        let api = HomeAssistantAPI(server: .fake())
        api.connection = connection
        let calendar = EKCalendar(for: .reminder, eventStore: store)
        func storeReminder(_ title: String) -> EKReminder {
            let reminder = EKReminder(eventStore: store)
            reminder.title = title
            return reminder
        }

        try await SettingsTestDatabase.with({ db in
            try RemindersSyncItemLink(
                configId: "config",
                todoItemUid: "u-deleted",
                reminderId: "r-orphan",
                lastKnownTitle: "Orphan",
                lastKnownCompleted: false,
                lastKnownNotes: nil,
                lastKnownDue: nil
            ).insert(db)
        }) { database in
            // A new item becomes a reminder.
            await #expect(throws: RefusingEventStore.Refusal(operation: "save")) {
                try await manager.applyPlan(
                    config: config(.toReminders),
                    api: api,
                    calendar: calendar,
                    features: nil,
                    todoSnapshots: ["u-new": snapshot("New item")],
                    remindersById: [:],
                    links: []
                )
            }
            // A changed item overwrites its reminder.
            let changed = storeReminder("Before")
            await #expect(throws: RefusingEventStore.Refusal(operation: "save")) {
                try await manager.applyPlan(
                    config: config(.toReminders),
                    api: api,
                    calendar: calendar,
                    features: [.setDueDateOnItem, .setDescriptionOnItem],
                    todoSnapshots: ["u-changed": snapshot("Changed")],
                    remindersById: ["r-changed": changed],
                    links: [link("u-changed", "r-changed", "Before")]
                )
            }
            #expect(changed.title == "Changed")
            // A deleted item removes its reminder, and its link goes first either way.
            await #expect(throws: RefusingEventStore.Refusal(operation: "remove")) {
                try await manager.applyPlan(
                    config: config(.toReminders),
                    api: api,
                    calendar: calendar,
                    features: nil,
                    todoSnapshots: [:],
                    remindersById: ["r-orphan": storeReminder("Orphan")],
                    links: [link("u-deleted", "r-orphan", "Orphan")]
                )
            }
            let remaining = try await database.read { db in
                try RemindersSyncItemLink.fetchAll(db).map(\.todoItemUid)
            }
            #expect(!remaining.contains("u-deleted"))
            // Nothing was sent to Home Assistant.
            #expect(connection.pendingRequests.isEmpty)
        }
    }

    @Test func historyLinesDescribeEachOperation() {
        let manager = RemindersSyncManager()
        let todo = ["u1": snapshot("Todo title")]
        let reminders = ["r1": snapshot("Reminder title")]
        let links = [link("u-linked", "r-linked", "Linked title")]

        func line(_ operation: RemindersSyncOperation) -> String? {
            manager.historyLine(for: operation, todoSnapshots: todo, reminderSnapshots: reminders, links: links)
        }

        #expect(
            line(.createReminder(todoItemUid: "u1")) == L10n.RemindersSync.History.Detail
                .createdReminder("Todo title")
        )
        #expect(line(.createReminder(todoItemUid: "missing")) == nil)
        #expect(
            line(.updateReminder(todoItemUid: "u1", reminderId: "r1")) == L10n.RemindersSync.History.Detail
                .updatedReminder("Todo title")
        )
        #expect(line(.updateReminder(todoItemUid: "missing", reminderId: "r1")) == nil)
        #expect(
            line(.deleteReminder(todoItemUid: "u1", reminderId: "r1")) == L10n.RemindersSync.History.Detail
                .deletedReminder("Reminder title")
        )
        // Without the reminder, the title comes from the stored link, or the uid as a last resort.
        #expect(
            line(.deleteReminder(todoItemUid: "u-linked", reminderId: "gone")) == L10n.RemindersSync.History
                .Detail.deletedReminder("Linked title")
        )
        #expect(
            line(.deleteReminder(todoItemUid: "u-unknown", reminderId: "gone")) == L10n.RemindersSync.History
                .Detail.deletedReminder("u-unknown")
        )
        #expect(
            line(.createTodoItem(reminderId: "r1")) == L10n.RemindersSync.History.Detail
                .createdItem("Reminder title")
        )
        #expect(line(.createTodoItem(reminderId: "missing")) == nil)
        #expect(
            line(.updateTodoItem(todoItemUid: "u1", reminderId: "r1")) == L10n.RemindersSync.History.Detail
                .updatedItem("Reminder title")
        )
        #expect(line(.updateTodoItem(todoItemUid: "u1", reminderId: "missing")) == nil)
        #expect(
            line(.deleteTodoItem(todoItemUid: "u1", reminderId: "r1")) == L10n.RemindersSync.History.Detail
                .deletedItem("Todo title")
        )
        #expect(
            line(.deleteTodoItem(todoItemUid: "u-linked", reminderId: "r1")) == L10n.RemindersSync.History
                .Detail.deletedItem("Linked title")
        )
        #expect(line(.adoptLink(todoItemUid: "u1", reminderId: "r1")) == nil)
        #expect(line(.deleteLink(todoItemUid: "u1")) == nil)
    }

    @Test func applyingAnItemCopiesEveryFieldTheListOwns() throws {
        let manager = RemindersSyncManager()
        let target = reminder("Old")
        target.notes = "Old notes"

        let item = RemindersSyncItemSnapshot(title: "New", isCompleted: true, notes: "New notes", due: "2026-07-18")
        manager.apply(item, to: target, features: nil)
        #expect(target.title == "New")
        #expect(target.isCompleted)
        #expect(target.notes == "New notes")
        #expect(target.dueDateComponents?.day == 18)
        #expect(target.dueDateComponents?.hour == nil)

        // A list without descriptions never overwrites the reminder's notes.
        let withoutNotes = RemindersSyncItemSnapshot(title: "New", isCompleted: false, notes: nil, due: "2026-07-18")
        manager.apply(withoutNotes, to: target, features: [.setDueDateOnItem])
        #expect(target.notes == "New notes")
        #expect(!target.isCompleted)
    }

    @Test func aDateOnlyListKeepsTheRemindersTime() throws {
        let manager = RemindersSyncManager()
        let target = reminder("Dentist")
        target.dueDateComponents = DateComponents(year: 2026, month: 7, day: 17, hour: 10, minute: 30, second: 0)

        let moved = RemindersSyncItemSnapshot(title: "Dentist", isCompleted: false, notes: nil, due: "2026-07-19")
        manager.apply(moved, to: target, features: [.setDueDateOnItem])

        let due = try #require(target.dueDateComponents)
        #expect(due.day == 19)
        #expect(due.hour == 10)
        #expect(due.minute == 30)

        // A timed value replaces the time as well.
        let timed = RemindersSyncItemSnapshot(
            title: "Dentist",
            isCompleted: false,
            notes: nil,
            due: TodoListItem.canonicalDueString(from: Date(timeIntervalSince1970: 1_790_000_000))
        )
        manager.apply(timed, to: target, features: nil)
        #expect(RemindersSyncItemSnapshot(reminder: target).due == timed.due)

        // Clearing the due date.
        let cleared = RemindersSyncItemSnapshot(title: "Dentist", isCompleted: false, notes: nil, due: nil)
        manager.apply(cleared, to: target, features: nil)
        #expect(target.dueDateComponents == nil)
    }

    @Test func snapshotsReadEachShapeOfReminderDueDate() {
        let target = reminder("Due")
        target.dueDateComponents = DateComponents(year: 2026, month: 1, day: 2)
        #expect(RemindersSyncItemSnapshot(reminder: target).due == "2026-01-02")
        target.dueDateComponents = DateComponents(year: 2026, month: 1, day: 2, hour: 9, minute: 0)
        #expect(RemindersSyncItemSnapshot(reminder: target).hasDueTime)
    }

    /// Without Reminders access (the simulator default) every entry point returns without syncing.
    ///
    /// The background refresh interval stays off: submitting a refresh request crashes a test host,
    /// where `RemindersSyncBackgroundRefresher.register()` never ran.
    @Test func entryPointsAreSafeWithoutRemindersAccess() async throws {
        let previousSettings = RemindersSyncSettings.current
        defer { previousSettings.save() }
        try await SettingsTestDatabase.with { _ in
            // A manager of the test's own, so the observers `start()` installs and the syncs it
            // schedules are torn down below, before the database is restored.
            let manager = RemindersSyncManager()
            let state = manager.authorizationState
            _ = await manager.reminderLists()

            // Installs the app-lifecycle observers (once) and schedules a sync. Nothing between
            // `start()` and `stopForTesting()` throws, so the teardown always runs.
            manager.start()
            let scheduledByStart = manager.pendingSyncTask
            #expect(scheduledByStart != nil)
            manager.start()
            #expect(manager.pendingSyncTask == scheduledByStart)

            // A Reminders change reschedules the sync, from a main-actor task the observer starts.
            NotificationCenter.default.post(name: .EKEventStoreChanged, object: nil)
            let deadline = Date().addingTimeInterval(10)
            while manager.pendingSyncTask == scheduledByStart, Date() < deadline {
                try? await Task.sleep(for: .milliseconds(10))
            }
            #expect(manager.pendingSyncTask != scheduledByStart)

            await manager.syncAll()
            #expect(!manager.isSyncing)
            manager.syncNow()

            var settings = previousSettings
            settings.backgroundRefreshInterval = 0
            settings.foregroundRefreshInterval = 15 * 60
            settings.save()
            manager.settingsChanged()
            settings.foregroundRefreshInterval = 0
            settings.save()
            manager.settingsChanged()
            #expect(manager.authorizationState == state)

            await manager.stopForTesting()
            #expect(manager.pendingSyncTask == nil)
        }
    }
}
