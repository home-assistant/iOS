import EventKit
import Foundation
import GRDB
import HAKit
import HAKit_Mocks
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import Testing

/// Drives sync passes with the completed-items setting on, against a connection that answers each
/// request synchronously, so the todo-side operations and the link bookkeeping run without
/// Reminders access or a server.
///
/// `.sharedState`: the manager moves its database work to detached tasks, which read the global
/// `Current.database`, and the setting lives in the app-group defaults; both are swapped for the
/// duration of each test.
@Suite(.sharedState)
@MainActor
struct RemindersSyncManagerCompletedItemsTests {
    private static let listId = "todo.shopping"
    private let eventStore = EKEventStore()

    private func config(_ direction: RemindersSyncDirection = .toHomeAssistant) -> RemindersSyncConfig {
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

    private func reminder(_ title: String, completed: Bool) -> EKReminder {
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = title
        reminder.isCompleted = completed
        return reminder
    }

    /// Runs `body` with an in-memory database, the completed-items setting switched on, and a
    /// connection that answers every request: the list fetch with `items`, `update_item` with
    /// `updateResult`, `add_item` for `failingAddTitle` with a failure, everything else with an
    /// empty success.
    private func withSyncEnvironment(
        items: [[String: Any]],
        updateResult: Result<HAData, HAError> = .success(.empty),
        failingAddTitle: String? = nil,
        _ body: (HomeAssistantAPI) async throws -> [String]
    ) async throws -> (details: [String], requests: [HARequest], links: [RemindersSyncItemLink]) {
        let database = try DatabaseQueue()
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        let previousDatabase = Current.database
        let previousSettings = RemindersSyncSettings.current
        Current.database = { database }
        RemindersSyncSettings(includeCompletedItems: true).save()
        defer {
            Current.database = previousDatabase
            previousSettings.save()
        }

        let connection = RemindersSyncAnsweringConnection { request in
            let type = "\(request.type)"
            if type.contains("get_items") {
                return .success(HAData(value: [
                    "changed_states": [Any](),
                    "service_response": [Self.listId: ["items": items]],
                ]))
            } else if type.contains("update_item") {
                return updateResult
            } else if type.contains("add_item"), request.data["item"] as? String == failingAddTitle {
                return .failure(.underlying(NSError(domain: "test", code: 2)))
            } else {
                return .success(.empty)
            }
        }
        let api = HomeAssistantAPI(server: .fake())
        api.connection = connection

        let details = try await body(api)
        let links = try await database.read { db in try RemindersSyncItemLink.fetchAll(db) }
        return (details, connection.requests, links)
    }

    private func applyPlan(
        api: HomeAssistantAPI,
        direction: RemindersSyncDirection = .toHomeAssistant,
        todoSnapshots: [String: RemindersSyncItemSnapshot] = [:],
        remindersById: [String: EKReminder]
    ) async throws -> [String] {
        // The manager and the calendar share the test's store: a reminder the manager creates
        // belongs to its store, and EventKit refuses to attach it to a calendar from any other.
        try await RemindersSyncManager(eventStore: eventStore).applyPlan(
            config: config(direction),
            api: api,
            calendar: EKCalendar(for: .reminder, eventStore: eventStore),
            features: nil,
            todoSnapshots: todoSnapshots,
            remindersById: remindersById,
            links: []
        )
    }

    /// Reminder-side writes go through EventKit, which refuses them here: the test host has no
    /// Reminders access and the calendar was never saved. The plan still reaches the write, the
    /// refusal is reported, and nothing is sent to Home Assistant.
    @Test func refusedReminderWriteIsReported() async throws {
        var thrown: Error?
        let (_, requests, links) = try await withSyncEnvironment(items: []) { api in
            do {
                return try await applyPlan(
                    api: api,
                    direction: .toReminders,
                    todoSnapshots: ["u-milk": RemindersSyncItemSnapshot(
                        title: "Milk",
                        isCompleted: false,
                        notes: nil,
                        due: nil
                    )],
                    remindersById: [:]
                )
            } catch {
                thrown = error
                return []
            }
        }

        #expect(thrown != nil)
        #expect(requests.isEmpty)
        #expect(links.isEmpty)
    }

    private func data(_ request: HARequest, _ key: String) -> String? {
        request.data[key] as? String
    }

    /// `todo.add_item` can't create a completed item, so a completed reminder is added, found
    /// again by title among the open items (not the older completed copy), and then completed.
    @Test func completedReminderIsCreatedThenCompletedInHomeAssistant() async throws {
        let (details, requests, links) = try await withSyncEnvironment(items: [
            ["summary": "Done", "uid": "old-done", "status": "completed"],
            ["summary": "Done", "uid": "new-done", "status": "needs_action"],
        ]) { api in
            try await applyPlan(api: api, remindersById: ["r-done": reminder("Done", completed: true)])
        }

        #expect(details == [L10n.RemindersSync.History.Detail.createdItem("Done")])

        let types = requests.map { "\($0.type)" }
        #expect(types.count == 3)
        #expect(types[0].contains("add_item"))
        #expect(types[1].contains("get_items"))
        #expect(types[2].contains("update_item"))
        #expect(data(requests[2], "item") == "new-done")
        #expect(data(requests[2], "status") == "completed")

        #expect(links.count == 1)
        #expect(links.first?.todoItemUid == "new-done")
        #expect(links.first?.reminderId == "r-done")
        #expect(links.first?.lastKnownCompleted == true)
    }

    /// When completing the created item fails, the item exists but is open, so the link records
    /// it as open: the next sync then completes it instead of reopening the reminder.
    @Test func failingToCompleteCreatedItemLinksItAsOpen() async throws {
        let (details, requests, links) = try await withSyncEnvironment(
            items: [["summary": "Done", "uid": "new-done", "status": "needs_action"]],
            updateResult: .failure(.underlying(NSError(domain: "test", code: 1)))
        ) { api in
            try await applyPlan(api: api, remindersById: ["r-done": reminder("Done", completed: true)])
        }

        #expect(details == [L10n.RemindersSync.History.Detail.createdItem("Done")])
        #expect(requests.map { "\($0.type)" }.last?.contains("update_item") == true)
        #expect(links.count == 1)
        #expect(links.first?.todoItemUid == "new-done")
        #expect(links.first?.lastKnownCompleted == false)
    }

    /// When a later operation in the same pass fails, the items already added to Home Assistant
    /// are still linked (and completed), so the next sync can't mistake them for new items.
    @Test func itemsAddedBeforeAFailureAreStillLinked() async throws {
        var thrown: Error?
        let (_, requests, links) = try await withSyncEnvironment(
            items: [["summary": "Done", "uid": "new-done", "status": "needs_action"]],
            failingAddTitle: "Fails"
        ) { api in
            do {
                return try await applyPlan(api: api, remindersById: [
                    "r-a-done": reminder("Done", completed: true),
                    "r-b-fails": reminder("Fails", completed: false),
                ])
            } catch {
                thrown = error
                return []
            }
        }

        #expect(thrown != nil)
        let types = requests.map { "\($0.type)" }
        #expect(types.filter { $0.contains("add_item") }.count == 2)
        #expect(types.last?.contains("update_item") == true)
        #expect(links.map(\.todoItemUid) == ["new-done"])
        #expect(links.first?.lastKnownCompleted == true)
    }

    /// An open reminder is created and linked without any `update_item` call.
    @Test func openReminderIsCreatedAndLinkedWithoutAnUpdate() async throws {
        let (details, requests, links) = try await withSyncEnvironment(items: [
            ["summary": "Milk", "uid": "new-milk", "status": "needs_action"],
        ]) { api in
            try await applyPlan(api: api, remindersById: ["r-milk": reminder("Milk", completed: false)])
        }

        #expect(details == [L10n.RemindersSync.History.Detail.createdItem("Milk")])
        #expect(requests.map { "\($0.type)" }.contains { $0.contains("update_item") } == false)
        #expect(links.map(\.todoItemUid) == ["new-milk"])
        #expect(links.first?.lastKnownCompleted == false)
    }
}
