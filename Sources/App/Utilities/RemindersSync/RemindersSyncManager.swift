import EventKit
import Foundation
import Shared
import UIKit

/// Orchestrates syncing between Apple Reminders lists and Home Assistant todo lists for every
/// stored `RemindersSyncConfig`. Fetches both sides, diffs them via `RemindersSyncPlanner` and
/// applies the resulting operations through EventKit and the todo services.
///
/// Syncs run when the app enters the foreground, when the Reminders database changes while the
/// app is running, and on demand from the settings screen.
@MainActor
final class RemindersSyncManager: ObservableObject {
    static let shared = RemindersSyncManager()

    enum AuthorizationState {
        case notDetermined
        case denied
        case authorized
    }

    @Published private(set) var isSyncing = false

    private var eventStore = EKEventStore()
    private var notificationObservers: [NSObjectProtocol] = []
    private var pendingSyncTask: Task<Void, Never>?
    /// Our own EventKit writes post `EKEventStoreChanged` too; suppress rescheduling while (and
    /// shortly after) a sync is running so it doesn't feed back into itself.
    private var suppressStoreChangeSync = false

    private init() {}

    /// Installs the foreground and Reminders-change observers. Called once at app launch; cheap
    /// when the user has no sync configured.
    func start() {
        guard notificationObservers.isEmpty else { return }

        notificationObservers.append(NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.suppressStoreChangeSync else { return }
                self.scheduleSync(after: 5)
            }
        })

        notificationObservers.append(NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.scheduleSync(after: 1)
            }
        })

        scheduleSync(after: 5)
    }

    var authorizationState: AuthorizationState {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .notDetermined:
            return .notDetermined
        case .authorized, .fullAccess:
            return .authorized
        default:
            return .denied
        }
    }

    /// Requests full access to Reminders (write-only access isn't enough to sync).
    func requestAccess() async -> Bool {
        do {
            let granted: Bool
            if #available(iOS 17.0, *) {
                granted = try await eventStore.requestFullAccessToReminders()
            } else {
                granted = try await eventStore.requestAccess(to: .reminder)
            }
            if granted {
                // A store created before the grant doesn't see the user's calendars.
                eventStore = EKEventStore()
            }
            objectWillChange.send()
            return granted
        } catch {
            Current.Log.error("Reminders access request failed: \(error.localizedDescription)")
            objectWillChange.send()
            return false
        }
    }

    /// The user's Reminders lists, for the configuration picker.
    func reminderLists() -> [EKCalendar] {
        eventStore.calendars(for: .reminder)
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    func syncNow() {
        pendingSyncTask?.cancel()
        pendingSyncTask = Task { [weak self] in
            await self?.syncAll()
        }
    }

    private func scheduleSync(after seconds: TimeInterval) {
        pendingSyncTask?.cancel()
        pendingSyncTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.syncAll()
        }
    }

    func syncAll() async {
        guard !isSyncing else { return }
        let configs = RemindersSyncConfig.all()
        guard !configs.isEmpty, authorizationState == .authorized else { return }

        isSyncing = true
        suppressStoreChangeSync = true
        for config in configs {
            do {
                try await sync(config)
            } catch {
                Current.Log.error(
                    "Reminders sync failed for \(config.todoEntityId) ↔ \(config.reminderListName): \(error.localizedDescription)"
                )
            }
        }
        isSyncing = false
        // EKEventStoreChanged notifications for our own writes can arrive slightly after commit.
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            self?.suppressStoreChangeSync = false
        }
    }

    private func sync(_ config: RemindersSyncConfig) async throws {
        guard let server = Current.servers.all.first(where: { $0.identifier.rawValue == config.serverId }),
              let api = Current.api(for: server) else {
            Current.Log.error("Reminders sync skipped, no server/API for \(config.serverId)")
            return
        }
        guard let calendar = eventStore.calendar(withIdentifier: config.reminderListId) else {
            Current.Log.error("Reminders sync skipped, list \(config.reminderListName) no longer exists")
            return
        }

        let todoItems = try await fetchTodoItems(api: api, listId: config.todoEntityId)
        let reminders = await fetchReminders(in: calendar)

        var todoSnapshots: [String: RemindersSyncItemSnapshot] = [:]
        for item in todoItems {
            todoSnapshots[item.uid] = RemindersSyncItemSnapshot(todoItem: item)
        }
        var remindersById: [String: EKReminder] = [:]
        var reminderSnapshots: [String: RemindersSyncItemSnapshot] = [:]
        for reminder in reminders {
            remindersById[reminder.calendarItemIdentifier] = reminder
            reminderSnapshots[reminder.calendarItemIdentifier] = RemindersSyncItemSnapshot(reminder: reminder)
        }

        let links = RemindersSyncItemLink.links(configId: config.id).map(RemindersSyncPlanner.LinkState.init(link:))
        let operations = RemindersSyncPlanner.plan(
            direction: config.direction,
            todoItems: todoSnapshots,
            reminders: reminderSnapshots,
            links: links
        )

        var createdTodoItemReminderIds: [String] = []
        var needsCommit = false

        for operation in operations {
            switch operation {
            case .createReminder, .updateReminder, .deleteReminder:
                let didWriteStore = try applyReminderOperation(
                    operation,
                    config: config,
                    calendar: calendar,
                    todoSnapshots: todoSnapshots,
                    remindersById: remindersById
                )
                needsCommit = needsCommit || didWriteStore
            case .createTodoItem, .updateTodoItem, .deleteTodoItem, .adoptLink, .deleteLink:
                let createdFromReminderId = try await applyTodoOperation(
                    operation,
                    config: config,
                    api: api,
                    todoSnapshots: todoSnapshots,
                    reminderSnapshots: reminderSnapshots
                )
                if let createdFromReminderId {
                    createdTodoItemReminderIds.append(createdFromReminderId)
                }
            }
        }

        if needsCommit {
            try eventStore.commit()
        }

        if !createdTodoItemReminderIds.isEmpty {
            try await linkCreatedTodoItems(
                config: config,
                api: api,
                reminderIds: createdTodoItemReminderIds,
                reminderSnapshots: reminderSnapshots
            )
        }

        var updated = config
        updated.lastSyncDate = Current.date()
        updated.save()
    }

    /// Applies an operation that writes to the Reminders side. Returns whether the event store
    /// needs a commit.
    private func applyReminderOperation(
        _ operation: RemindersSyncOperation,
        config: RemindersSyncConfig,
        calendar: EKCalendar,
        todoSnapshots: [String: RemindersSyncItemSnapshot],
        remindersById: [String: EKReminder]
    ) throws -> Bool {
        switch operation {
        case let .createReminder(todoItemUid):
            guard let snapshot = todoSnapshots[todoItemUid] else { return false }
            let reminder = EKReminder(eventStore: eventStore)
            reminder.calendar = calendar
            apply(snapshot, to: reminder)
            try eventStore.save(reminder, commit: false)
            saveLink(
                config: config,
                todoItemUid: todoItemUid,
                reminderId: reminder.calendarItemIdentifier,
                snapshot: snapshot
            )
            return true
        case let .updateReminder(todoItemUid, reminderId):
            guard let snapshot = todoSnapshots[todoItemUid],
                  let reminder = remindersById[reminderId] else { return false }
            apply(snapshot, to: reminder)
            try eventStore.save(reminder, commit: false)
            saveLink(config: config, todoItemUid: todoItemUid, reminderId: reminderId, snapshot: snapshot)
            return true
        case let .deleteReminder(todoItemUid, reminderId):
            defer { RemindersSyncItemLink.delete(configId: config.id, todoItemUid: todoItemUid) }
            guard let reminder = remindersById[reminderId] else { return false }
            try eventStore.remove(reminder, commit: false)
            return true
        default:
            return false
        }
    }

    /// Applies an operation that writes to the Home Assistant side or only touches links.
    /// Returns the source reminder identifier when a todo item was created, so the caller can
    /// link it after re-fetching the list.
    private func applyTodoOperation(
        _ operation: RemindersSyncOperation,
        config: RemindersSyncConfig,
        api: HomeAssistantAPI,
        todoSnapshots: [String: RemindersSyncItemSnapshot],
        reminderSnapshots: [String: RemindersSyncItemSnapshot]
    ) async throws -> String? {
        switch operation {
        case let .createTodoItem(reminderId):
            guard let snapshot = reminderSnapshots[reminderId] else { return nil }
            try await api.addTodoItem(
                listId: config.todoEntityId,
                summary: snapshot.title,
                description: snapshot.notes,
                dueDate: snapshot.dueDateArgument,
                dueDateTime: snapshot.dueDateTimeArgument
            )
            return reminderId
        case let .updateTodoItem(todoItemUid, reminderId):
            guard let snapshot = reminderSnapshots[reminderId] else { return nil }
            try await api.updateTodoItem(
                listId: config.todoEntityId,
                itemId: todoItemUid,
                rename: snapshot.title,
                status: snapshot.isCompleted ? "completed" : "needs_action",
                description: snapshot.notes,
                dueDate: snapshot.dueDateArgument,
                dueDateTime: snapshot.dueDateTimeArgument
            )
            saveLink(config: config, todoItemUid: todoItemUid, reminderId: reminderId, snapshot: snapshot)
            return nil
        case let .deleteTodoItem(todoItemUid, _):
            try await api.removeTodoItem(
                listId: config.todoEntityId,
                itemId: todoItemUid
            )
            RemindersSyncItemLink.delete(configId: config.id, todoItemUid: todoItemUid)
            return nil
        case let .adoptLink(todoItemUid, reminderId):
            guard let snapshot = todoSnapshots[todoItemUid] ?? reminderSnapshots[reminderId] else { return nil }
            saveLink(config: config, todoItemUid: todoItemUid, reminderId: reminderId, snapshot: snapshot)
            return nil
        case let .deleteLink(todoItemUid):
            RemindersSyncItemLink.delete(configId: config.id, todoItemUid: todoItemUid)
            return nil
        default:
            return nil
        }
    }

    /// `todo.add_item` doesn't return the created item's `uid`, so items created on the Home
    /// Assistant side are linked by re-fetching the list and matching still-unlinked items by
    /// title.
    private func linkCreatedTodoItems(
        config: RemindersSyncConfig,
        api: HomeAssistantAPI,
        reminderIds: [String],
        reminderSnapshots: [String: RemindersSyncItemSnapshot]
    ) async throws {
        let refreshed = try await fetchTodoItems(api: api, listId: config.todoEntityId)
        let linkedUids = Set(RemindersSyncItemLink.links(configId: config.id).map(\.todoItemUid))
        var unlinkedItems = refreshed.filter { !linkedUids.contains($0.uid) }

        for reminderId in reminderIds {
            guard let snapshot = reminderSnapshots[reminderId],
                  let index = unlinkedItems
                  .firstIndex(where: { RemindersSyncItemSnapshot(todoItem: $0).title == snapshot.title }) else { continue }
            let item = unlinkedItems.remove(at: index)
            saveLink(config: config, todoItemUid: item.uid, reminderId: reminderId, snapshot: snapshot)
        }
    }

    private func fetchTodoItems(api: HomeAssistantAPI, listId: String) async throws -> [TodoListItem] {
        try await api.todoListItems(listId: listId)
    }

    private func fetchReminders(in calendar: EKCalendar) async -> [EKReminder] {
        await withCheckedContinuation { continuation in
            let predicate = eventStore.predicateForReminders(in: [calendar])
            eventStore.fetchReminders(matching: predicate) { reminders in
                continuation.resume(returning: reminders ?? [])
            }
        }
    }

    private func apply(_ snapshot: RemindersSyncItemSnapshot, to reminder: EKReminder) {
        reminder.title = snapshot.title
        reminder.notes = snapshot.notes
        reminder.isCompleted = snapshot.isCompleted
        reminder.dueDateComponents = snapshot.dueComponents
    }

    private func saveLink(
        config: RemindersSyncConfig,
        todoItemUid: String,
        reminderId: String,
        snapshot: RemindersSyncItemSnapshot
    ) {
        RemindersSyncItemLink(
            configId: config.id,
            todoItemUid: todoItemUid,
            reminderId: reminderId,
            lastKnownTitle: snapshot.title,
            lastKnownCompleted: snapshot.isCompleted,
            lastKnownNotes: snapshot.notes,
            lastKnownDue: snapshot.due
        ).save()
    }
}
