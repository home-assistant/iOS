import EventKit
import Foundation
import PromiseKit
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
    private var periodicRefreshTask: Task<Void, Never>?
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
                self?.restartPeriodicRefresh()
            }
        })

        notificationObservers.append(NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.appDidEnterBackground()
            }
        })

        scheduleSync(after: 5)
        restartPeriodicRefresh()
    }

    /// Backgrounding: stop the debounce and periodic-refresh timers so a sync can't start during
    /// the background-execution grace window without protection; both are re-armed on the next
    /// foreground. A sync that is already running is left alone — it holds a background task for
    /// its whole duration — but `LifecycleManager` has just suspended GRDB underneath it, so
    /// resume the database for the remainder of the protected sync (this runs after
    /// LifecycleManager's handler because it hops onto the main actor in a fresh task); `syncAll`
    /// re-suspends when it finishes.
    private func appDidEnterBackground() {
        if isSyncing {
            AppDatabaseSuspension.resume()
        } else {
            pendingSyncTask?.cancel()
            pendingSyncTask = nil
            periodicRefreshTask?.cancel()
            periodicRefreshTask = nil
        }
    }

    /// Called when the user changes the sync settings: restarts the foreground refresh timer and
    /// re-requests background refreshes with the new frequency.
    func settingsChanged() {
        restartPeriodicRefresh()
        RemindersSyncBackgroundRefresher.schedule()
    }

    /// Periodically re-fetches the Home Assistant side while the app is open, since HA-side
    /// changes don't push a notification the way `EKEventStoreChanged` does for Reminders.
    private func restartPeriodicRefresh() {
        periodicRefreshTask?.cancel()
        let interval = RemindersSyncSettings.current.foregroundRefreshInterval
        guard interval > 0 else {
            periodicRefreshTask = nil
            return
        }
        periodicRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard !Task.isCancelled else { return }
                await self?.syncAll()
            }
        }
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
        guard !isSyncing, authorizationState == .authorized else { return }

        // GRDB is suspended whenever the app is backgrounded (LifecycleManager); resume it so the
        // config read and the sync's writes also work from a background refresh. Every exit path
        // below re-suspends while still backgrounded.
        AppDatabaseSuspension.resume()
        let configs = await Self.databaseAccess { RemindersSyncConfig.all() }
        guard !configs.isEmpty else {
            suspendDatabaseIfBackgrounded()
            return
        }

        isSyncing = true
        suppressStoreChangeSync = true

        // Hold a background task for the duration of the sync: getting suspended while a sync
        // write was mid-commit held the app-group SQLite file lock and killed the app with
        // 0xdead10cc (see the suspension notes in GRDB+Initialization.swift).
        let (untilSyncEnds, syncEndSeal) = Promise<Void>.pending()
        let syncTask = Task { [weak self] in
            await self?.sync(configs: configs)
        }
        Current.backgroundTask(withName: BackgroundTask.remindersSync.rawValue) { _ in untilSyncEnds }
            .catch { _ in
                // Out of background time: stop syncing and suspend GRDB right away, aborting any
                // in-flight write so the file lock is released before the process is frozen.
                syncTask.cancel()
                AppDatabaseSuspension.suspend()
            }
        // Backgrounding between the resume above and this point suspends GRDB again
        // (LifecycleManager); undo that now that the background task is held.
        AppDatabaseSuspension.resume()
        await syncTask.value
        syncEndSeal.fulfill(())
        suspendDatabaseIfBackgrounded()

        isSyncing = false
        // EKEventStoreChanged notifications for our own writes can arrive slightly after commit.
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            self?.suppressStoreChangeSync = false
        }
    }

    private func sync(configs: [RemindersSyncConfig]) async {
        for config in configs {
            // Cancelled when the background task expires; whatever didn't finish syncs next time.
            guard !Task.isCancelled else { return }
            do {
                try await sync(config)
            } catch {
                Current.Log.error(
                    "Reminders sync failed for \(config.todoEntityId) ↔ \(config.reminderListName): \(error.localizedDescription)"
                )
            }
        }
    }

    /// Runs synchronous GRDB access on a background thread instead of the main actor. The
    /// 0xdead10cc termination this sync used to hit showed the main thread blocked in a commit's
    /// `fsync`: it couldn't service the `didEnterBackground` notification that suspends GRDB and
    /// was still holding the app-group SQLite lock when the process was frozen.
    private nonisolated static func databaseAccess<T: Sendable>(
        _ access: @escaping @Sendable () -> T
    ) async -> T {
        await Task.detached { access() }.value
    }

    /// Counterpart to `LifecycleManager`'s suspend-on-background: after the sync touches the
    /// database while backgrounded, GRDB goes back to the suspended state so nothing can hold the
    /// app-group SQLite lock when the process is frozen.
    private func suspendDatabaseIfBackgrounded() {
        if UIApplication.shared.applicationState == .background {
            AppDatabaseSuspension.suspend()
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

        var details: [String] = []
        do {
            let todoItems = try await fetchTodoItems(api: api, listId: config.todoEntityId)
            let reminders = await fetchReminders(in: calendar)
            let todoSnapshots = Dictionary(
                todoItems.map { ($0.uid, RemindersSyncItemSnapshot(todoItem: $0)) },
                uniquingKeysWith: { first, _ in first }
            )
            let remindersById = Dictionary(
                reminders.map { ($0.calendarItemIdentifier, $0) },
                uniquingKeysWith: { first, _ in first }
            )

            let configId = config.id
            let links = await Self.databaseAccess { RemindersSyncItemLink.links(configId: configId) }
                .map(RemindersSyncPlanner.LinkState.init(link:))
            details = try await applyPlan(
                config: config,
                api: api,
                calendar: calendar,
                todoSnapshots: todoSnapshots,
                remindersById: remindersById,
                links: links
            )
        } catch {
            await recordHistory(config: config, error: error, details: details)
            throw error
        }

        // Unchanged runs aren't recorded, so history stays a log of actual changes.
        if !details.isEmpty {
            await recordHistory(config: config, error: nil, details: details)
        }

        var updated = config
        updated.lastSyncDate = Current.date()
        let configToSave = updated
        await Self.databaseAccess { configToSave.save() }
    }

    /// Plans and applies the operations for one config. Returns the history detail lines for the
    /// changes that were applied.
    private func applyPlan(
        config: RemindersSyncConfig,
        api: HomeAssistantAPI,
        calendar: EKCalendar,
        todoSnapshots: [String: RemindersSyncItemSnapshot],
        remindersById: [String: EKReminder],
        links: [RemindersSyncPlanner.LinkState]
    ) async throws -> [String] {
        let reminderSnapshots = remindersById.mapValues(RemindersSyncItemSnapshot.init(reminder:))
        let operations = RemindersSyncPlanner.plan(
            direction: config.direction,
            conflictResolution: RemindersSyncSettings.current.conflictResolution,
            todoItems: todoSnapshots,
            reminders: reminderSnapshots,
            links: links
        )

        var details: [String] = []
        var createdTodoItemReminderIds: [String] = []
        var needsCommit = false

        for operation in operations {
            switch operation {
            case .createReminder, .updateReminder, .deleteReminder:
                let didWriteStore = try await applyReminderOperation(
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
            if let line = historyLine(
                for: operation,
                todoSnapshots: todoSnapshots,
                reminderSnapshots: reminderSnapshots,
                links: links
            ) {
                details.append(line)
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

        return details
    }

    private func recordHistory(config: RemindersSyncConfig, error: Error?, details: [String]) async {
        let entry = RemindersSyncHistoryEntry(
            id: UUID().uuidString,
            configId: config.id,
            listLabel: "\(config.reminderListName) ↔ \(config.todoEntityName)",
            date: Current.date(),
            success: error == nil,
            error: error?.localizedDescription,
            details: details.joined(separator: "\n")
        )
        await Self.databaseAccess { entry.save() }
    }

    /// A localized, human-readable line for the history log describing one applied operation.
    /// Link bookkeeping operations return nil, they aren't user-visible changes.
    private func historyLine(
        for operation: RemindersSyncOperation,
        todoSnapshots: [String: RemindersSyncItemSnapshot],
        reminderSnapshots: [String: RemindersSyncItemSnapshot],
        links: [RemindersSyncPlanner.LinkState]
    ) -> String? {
        func linkTitle(_ todoItemUid: String) -> String {
            links.first(where: { $0.todoItemUid == todoItemUid })?.snapshot.title ?? todoItemUid
        }

        switch operation {
        case let .createReminder(todoItemUid):
            guard let title = todoSnapshots[todoItemUid]?.title else { return nil }
            return L10n.RemindersSync.History.Detail.createdReminder(title)
        case let .updateReminder(todoItemUid, _):
            guard let title = todoSnapshots[todoItemUid]?.title else { return nil }
            return L10n.RemindersSync.History.Detail.updatedReminder(title)
        case let .deleteReminder(todoItemUid, reminderId):
            let title = reminderSnapshots[reminderId]?.title ?? linkTitle(todoItemUid)
            return L10n.RemindersSync.History.Detail.deletedReminder(title)
        case let .createTodoItem(reminderId):
            guard let title = reminderSnapshots[reminderId]?.title else { return nil }
            return L10n.RemindersSync.History.Detail.createdItem(title)
        case let .updateTodoItem(_, reminderId):
            guard let title = reminderSnapshots[reminderId]?.title else { return nil }
            return L10n.RemindersSync.History.Detail.updatedItem(title)
        case let .deleteTodoItem(todoItemUid, _):
            let title = todoSnapshots[todoItemUid]?.title ?? linkTitle(todoItemUid)
            return L10n.RemindersSync.History.Detail.deletedItem(title)
        case .adoptLink, .deleteLink:
            return nil
        }
    }

    /// Applies an operation that writes to the Reminders side. Returns whether the event store
    /// needs a commit.
    private func applyReminderOperation(
        _ operation: RemindersSyncOperation,
        config: RemindersSyncConfig,
        calendar: EKCalendar,
        todoSnapshots: [String: RemindersSyncItemSnapshot],
        remindersById: [String: EKReminder]
    ) async throws -> Bool {
        switch operation {
        case let .createReminder(todoItemUid):
            guard let snapshot = todoSnapshots[todoItemUid] else { return false }
            let reminder = EKReminder(eventStore: eventStore)
            reminder.calendar = calendar
            apply(snapshot, to: reminder)
            try eventStore.save(reminder, commit: false)
            await saveLink(
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
            await saveLink(config: config, todoItemUid: todoItemUid, reminderId: reminderId, snapshot: snapshot)
            return true
        case let .deleteReminder(todoItemUid, reminderId):
            // The link row goes away regardless of whether the reminder still exists or its
            // removal fails (this used to be a `defer`); deleting it first keeps that behavior
            // now that the write needs an await.
            let configId = config.id
            await Self.databaseAccess { RemindersSyncItemLink.delete(configId: configId, todoItemUid: todoItemUid) }
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
            await saveLink(config: config, todoItemUid: todoItemUid, reminderId: reminderId, snapshot: snapshot)
            return nil
        case let .deleteTodoItem(todoItemUid, _):
            try await api.removeTodoItem(
                listId: config.todoEntityId,
                itemId: todoItemUid
            )
            let configId = config.id
            await Self.databaseAccess { RemindersSyncItemLink.delete(configId: configId, todoItemUid: todoItemUid) }
            return nil
        case let .adoptLink(todoItemUid, reminderId):
            guard let snapshot = todoSnapshots[todoItemUid] ?? reminderSnapshots[reminderId] else { return nil }
            await saveLink(config: config, todoItemUid: todoItemUid, reminderId: reminderId, snapshot: snapshot)
            return nil
        case let .deleteLink(todoItemUid):
            let configId = config.id
            await Self.databaseAccess { RemindersSyncItemLink.delete(configId: configId, todoItemUid: todoItemUid) }
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
        let configId = config.id
        let existingLinks = await Self.databaseAccess { RemindersSyncItemLink.links(configId: configId) }
        let linkedUids = Set(existingLinks.map(\.todoItemUid))
        var unlinkedItems = refreshed.filter { !linkedUids.contains($0.uid) }

        for reminderId in reminderIds {
            guard let snapshot = reminderSnapshots[reminderId],
                  let index = unlinkedItems
                  .firstIndex(where: { RemindersSyncItemSnapshot(todoItem: $0).title == snapshot.title }) else { continue }
            let item = unlinkedItems.remove(at: index)
            await saveLink(config: config, todoItemUid: item.uid, reminderId: reminderId, snapshot: snapshot)
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
    ) async {
        let link = RemindersSyncItemLink(
            configId: config.id,
            todoItemUid: todoItemUid,
            reminderId: reminderId,
            lastKnownTitle: snapshot.title,
            lastKnownCompleted: snapshot.isCompleted,
            lastKnownNotes: snapshot.notes,
            lastKnownDue: snapshot.due
        )
        await Self.databaseAccess { link.save() }
    }
}
