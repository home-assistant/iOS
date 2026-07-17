import Foundation
import Shared

/// Pure diffing logic for one sync pass: given the current Home Assistant items, the current
/// reminders, and the links stored at the last sync, produces the operations that bring both
/// sides back in agreement for the configured direction. Has no side effects, so it can be unit
/// tested without EventKit or a server.
enum RemindersSyncPlanner {
    /// The persisted link state, decoupled from the GRDB record.
    struct LinkState: Equatable {
        let todoItemUid: String
        let reminderId: String
        let snapshot: RemindersSyncItemSnapshot

        init(todoItemUid: String, reminderId: String, snapshot: RemindersSyncItemSnapshot) {
            self.todoItemUid = todoItemUid
            self.reminderId = reminderId
            self.snapshot = snapshot
        }

        init(link: RemindersSyncItemLink) {
            self.todoItemUid = link.todoItemUid
            self.reminderId = link.reminderId
            self.snapshot = RemindersSyncItemSnapshot(
                title: link.lastKnownTitle,
                isCompleted: link.lastKnownCompleted,
                notes: link.lastKnownNotes,
                due: link.lastKnownDue
            )
        }
    }

    static func plan(
        direction: RemindersSyncDirection,
        conflictResolution: RemindersSyncConflictResolution = .homeAssistant,
        todoItems: [String: RemindersSyncItemSnapshot],
        reminders: [String: RemindersSyncItemSnapshot],
        links: [LinkState]
    ) -> [RemindersSyncOperation] {
        var operations: [RemindersSyncOperation] = []
        var linkedUids = Set<String>()
        var linkedReminderIds = Set<String>()

        for link in links {
            linkedUids.insert(link.todoItemUid)
            linkedReminderIds.insert(link.reminderId)
            let todoItem = todoItems[link.todoItemUid]
            let reminder = reminders[link.reminderId]

            switch (todoItem, reminder) {
            case let (.some(todoItem), .some(reminder)):
                if todoItem == reminder {
                    // Both sides agree; refresh the stored snapshot if it went stale
                    // (e.g. the same edit was made on both sides).
                    if todoItem != link.snapshot {
                        operations.append(.adoptLink(todoItemUid: link.todoItemUid, reminderId: link.reminderId))
                    }
                    continue
                }
                let todoChanged = todoItem != link.snapshot
                let reminderChanged = reminder != link.snapshot
                switch direction {
                case .bothWays:
                    if reminderChanged, !todoChanged {
                        operations
                            .append(.updateTodoItem(todoItemUid: link.todoItemUid, reminderId: link.reminderId))
                    } else if todoChanged, !reminderChanged {
                        operations
                            .append(.updateReminder(todoItemUid: link.todoItemUid, reminderId: link.reminderId))
                    } else {
                        // Both changed (or the stored snapshot is stale): the configured side wins.
                        switch conflictResolution {
                        case .homeAssistant:
                            operations
                                .append(.updateReminder(todoItemUid: link.todoItemUid, reminderId: link.reminderId))
                        case .reminders:
                            operations
                                .append(.updateTodoItem(todoItemUid: link.todoItemUid, reminderId: link.reminderId))
                        }
                    }
                case .toReminders:
                    operations.append(.updateReminder(todoItemUid: link.todoItemUid, reminderId: link.reminderId))
                case .toHomeAssistant:
                    operations.append(.updateTodoItem(todoItemUid: link.todoItemUid, reminderId: link.reminderId))
                }
            case let (.some(todoItem), .none):
                // The reminder was deleted.
                switch direction {
                case .bothWays, .toHomeAssistant:
                    operations.append(.deleteTodoItem(todoItemUid: link.todoItemUid, reminderId: link.reminderId))
                case .toReminders:
                    // Reminders only mirrors HA; restore the deleted reminder, unless it's
                    // completed history not worth resurrecting.
                    if todoItem.isCompleted {
                        operations.append(.deleteLink(todoItemUid: link.todoItemUid))
                    } else {
                        operations.append(.createReminder(todoItemUid: link.todoItemUid))
                    }
                }
            case let (.none, .some(reminder)):
                // The Home Assistant item was deleted.
                switch direction {
                case .bothWays, .toReminders:
                    operations.append(.deleteReminder(todoItemUid: link.todoItemUid, reminderId: link.reminderId))
                case .toHomeAssistant:
                    // HA only mirrors Reminders; restore the deleted item, unless it's completed
                    // history not worth resurrecting.
                    if reminder.isCompleted {
                        operations.append(.deleteLink(todoItemUid: link.todoItemUid))
                    } else {
                        operations.append(.createTodoItem(reminderId: link.reminderId))
                    }
                }
            case (.none, .none):
                operations.append(.deleteLink(todoItemUid: link.todoItemUid))
            }
        }

        // Completed items that were never linked are ignored: they are history, not work to
        // mirror. Completion still propagates across linked pairs above.
        var unlinkedTodoUids = todoItems
            .filter { !linkedUids.contains($0.key) && !$0.value.isCompleted }
            .keys.sorted()
        var unlinkedReminderIds = reminders
            .filter { !linkedReminderIds.contains($0.key) && !$0.value.isCompleted }
            .keys.sorted()

        // Adopt same-titled unlinked pairs first, so linking two lists that already contain the
        // same items doesn't create duplicates on the first sync.
        for uid in unlinkedTodoUids {
            guard let todoItem = todoItems[uid],
                  let reminderId = unlinkedReminderIds
                  .first(where: { reminders[$0]?.title == todoItem.title }) else { continue }
            unlinkedReminderIds.removeAll { $0 == reminderId }
            unlinkedTodoUids.removeAll { $0 == uid }
            operations.append(.adoptLink(todoItemUid: uid, reminderId: reminderId))
            if let reminder = reminders[reminderId], reminder != todoItem {
                switch direction {
                case .bothWays, .toReminders:
                    operations.append(.updateReminder(todoItemUid: uid, reminderId: reminderId))
                case .toHomeAssistant:
                    operations.append(.updateTodoItem(todoItemUid: uid, reminderId: reminderId))
                }
            }
        }

        // Remaining unlinked items are created on the other side. One-way syncs never touch items
        // that exist only on their target side.
        for uid in unlinkedTodoUids {
            switch direction {
            case .bothWays, .toReminders:
                operations.append(.createReminder(todoItemUid: uid))
            case .toHomeAssistant:
                break
            }
        }
        for reminderId in unlinkedReminderIds {
            switch direction {
            case .bothWays, .toHomeAssistant:
                operations.append(.createTodoItem(reminderId: reminderId))
            case .toReminders:
                break
            }
        }

        return operations
    }
}
