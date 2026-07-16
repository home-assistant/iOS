@testable import HomeAssistant
@testable import Shared
import Testing

struct RemindersSyncPlannerTests {
    private func snapshot(
        title: String = "Buy milk",
        isCompleted: Bool = false,
        notes: String? = nil,
        due: String? = nil
    ) -> RemindersSyncItemSnapshot {
        RemindersSyncItemSnapshot(title: title, isCompleted: isCompleted, notes: notes, due: due)
    }

    private func link(
        todoItemUid: String = "todo-1",
        reminderId: String = "reminder-1",
        snapshot: RemindersSyncItemSnapshot
    ) -> RemindersSyncPlanner.LinkState {
        .init(todoItemUid: todoItemUid, reminderId: reminderId, snapshot: snapshot)
    }

    // MARK: - Empty and unchanged inputs

    @Test func testEmptyInputsProduceNoOperations() {
        for direction in RemindersSyncDirection.allCases {
            let operations = RemindersSyncPlanner.plan(
                direction: direction,
                todoItems: [:],
                reminders: [:],
                links: []
            )
            #expect(operations.isEmpty)
        }
    }

    @Test func testLinkedUnchangedPairProducesNoOperations() {
        let item = snapshot()
        for direction in RemindersSyncDirection.allCases {
            let operations = RemindersSyncPlanner.plan(
                direction: direction,
                todoItems: ["todo-1": item],
                reminders: ["reminder-1": item],
                links: [link(snapshot: item)]
            )
            #expect(operations.isEmpty)
        }
    }

    @Test func testLinkedPairEqualButStaleSnapshotRefreshesLink() {
        // The same edit was made on both sides; only the stored snapshot is out of date.
        let item = snapshot(title: "Buy oat milk")
        let operations = RemindersSyncPlanner.plan(
            direction: .bothWays,
            todoItems: ["todo-1": item],
            reminders: ["reminder-1": item],
            links: [link(snapshot: snapshot(title: "Buy milk"))]
        )
        #expect(operations == [.adoptLink(todoItemUid: "todo-1", reminderId: "reminder-1")])
    }

    // MARK: - Creating items for unlinked entries

    @Test func testUnlinkedTodoItemCreatesReminderUnlessSyncingToHomeAssistant() {
        let todoItems = ["todo-1": snapshot()]

        for direction in [RemindersSyncDirection.bothWays, .toReminders] {
            let operations = RemindersSyncPlanner.plan(
                direction: direction,
                todoItems: todoItems,
                reminders: [:],
                links: []
            )
            #expect(operations == [.createReminder(todoItemUid: "todo-1")])
        }

        let operations = RemindersSyncPlanner.plan(
            direction: .toHomeAssistant,
            todoItems: todoItems,
            reminders: [:],
            links: []
        )
        #expect(operations.isEmpty)
    }

    @Test func testUnlinkedReminderCreatesTodoItemUnlessSyncingToReminders() {
        let reminders = ["reminder-1": snapshot()]

        for direction in [RemindersSyncDirection.bothWays, .toHomeAssistant] {
            let operations = RemindersSyncPlanner.plan(
                direction: direction,
                todoItems: [:],
                reminders: reminders,
                links: []
            )
            #expect(operations == [.createTodoItem(reminderId: "reminder-1")])
        }

        let operations = RemindersSyncPlanner.plan(
            direction: .toReminders,
            todoItems: [:],
            reminders: reminders,
            links: []
        )
        #expect(operations.isEmpty)
    }

    // MARK: - Adopting same-titled unlinked pairs

    @Test func testUnlinkedItemsWithSameTitleAreAdoptedInsteadOfDuplicated() {
        let item = snapshot()
        let operations = RemindersSyncPlanner.plan(
            direction: .bothWays,
            todoItems: ["todo-1": item],
            reminders: ["reminder-1": item],
            links: []
        )
        #expect(operations == [.adoptLink(todoItemUid: "todo-1", reminderId: "reminder-1")])
    }

    @Test func testAdoptedPairWithDifferentContentIsAlignedPerDirection() {
        let todoItems = ["todo-1": snapshot(isCompleted: true)]
        let reminders = ["reminder-1": snapshot(isCompleted: false)]

        for direction in [RemindersSyncDirection.bothWays, .toReminders] {
            let operations = RemindersSyncPlanner.plan(
                direction: direction,
                todoItems: todoItems,
                reminders: reminders,
                links: []
            )
            #expect(operations == [
                .adoptLink(todoItemUid: "todo-1", reminderId: "reminder-1"),
                .updateReminder(todoItemUid: "todo-1", reminderId: "reminder-1"),
            ])
        }

        let operations = RemindersSyncPlanner.plan(
            direction: .toHomeAssistant,
            todoItems: todoItems,
            reminders: reminders,
            links: []
        )
        #expect(operations == [
            .adoptLink(todoItemUid: "todo-1", reminderId: "reminder-1"),
            .updateTodoItem(todoItemUid: "todo-1", reminderId: "reminder-1"),
        ])
    }

    // MARK: - Propagating edits on linked pairs

    @Test func testReminderEditPropagatesToHomeAssistantWhenSyncingBothWays() {
        let original = snapshot()
        let operations = RemindersSyncPlanner.plan(
            direction: .bothWays,
            todoItems: ["todo-1": original],
            reminders: ["reminder-1": snapshot(isCompleted: true)],
            links: [link(snapshot: original)]
        )
        #expect(operations == [.updateTodoItem(todoItemUid: "todo-1", reminderId: "reminder-1")])
    }

    @Test func testTodoItemEditPropagatesToRemindersWhenSyncingBothWays() {
        let original = snapshot()
        let operations = RemindersSyncPlanner.plan(
            direction: .bothWays,
            todoItems: ["todo-1": snapshot(title: "Buy oat milk")],
            reminders: ["reminder-1": original],
            links: [link(snapshot: original)]
        )
        #expect(operations == [.updateReminder(todoItemUid: "todo-1", reminderId: "reminder-1")])
    }

    @Test func testConflictingEditsResolveInFavorOfHomeAssistant() {
        let operations = RemindersSyncPlanner.plan(
            direction: .bothWays,
            todoItems: ["todo-1": snapshot(title: "HA edit")],
            reminders: ["reminder-1": snapshot(title: "Reminders edit")],
            links: [link(snapshot: snapshot())]
        )
        #expect(operations == [.updateReminder(todoItemUid: "todo-1", reminderId: "reminder-1")])
    }

    @Test func testOneWaySyncAlwaysOverwritesTheTargetSide() {
        let original = snapshot()
        // Even though only the reminder changed, syncing to Reminders overwrites the reminder.
        let toReminders = RemindersSyncPlanner.plan(
            direction: .toReminders,
            todoItems: ["todo-1": original],
            reminders: ["reminder-1": snapshot(isCompleted: true)],
            links: [link(snapshot: original)]
        )
        #expect(toReminders == [.updateReminder(todoItemUid: "todo-1", reminderId: "reminder-1")])

        // And vice versa: only the todo item changed, but Reminders is the source of truth.
        let toHomeAssistant = RemindersSyncPlanner.plan(
            direction: .toHomeAssistant,
            todoItems: ["todo-1": snapshot(title: "HA edit")],
            reminders: ["reminder-1": original],
            links: [link(snapshot: original)]
        )
        #expect(toHomeAssistant == [.updateTodoItem(todoItemUid: "todo-1", reminderId: "reminder-1")])
    }

    // MARK: - Deletions

    @Test func testDeletedReminderDeletesTodoItemUnlessRemindersOnlyMirrors() {
        let item = snapshot()

        for direction in [RemindersSyncDirection.bothWays, .toHomeAssistant] {
            let operations = RemindersSyncPlanner.plan(
                direction: direction,
                todoItems: ["todo-1": item],
                reminders: [:],
                links: [link(snapshot: item)]
            )
            #expect(operations == [.deleteTodoItem(todoItemUid: "todo-1", reminderId: "reminder-1")])
        }

        // Reminders only mirrors HA, so the deleted reminder is restored instead.
        let operations = RemindersSyncPlanner.plan(
            direction: .toReminders,
            todoItems: ["todo-1": item],
            reminders: [:],
            links: [link(snapshot: item)]
        )
        #expect(operations == [.createReminder(todoItemUid: "todo-1")])
    }

    @Test func testDeletedTodoItemDeletesReminderUnlessHomeAssistantOnlyMirrors() {
        let item = snapshot()

        for direction in [RemindersSyncDirection.bothWays, .toReminders] {
            let operations = RemindersSyncPlanner.plan(
                direction: direction,
                todoItems: [:],
                reminders: ["reminder-1": item],
                links: [link(snapshot: item)]
            )
            #expect(operations == [.deleteReminder(todoItemUid: "todo-1", reminderId: "reminder-1")])
        }

        // HA only mirrors Reminders, so the deleted item is restored instead.
        let operations = RemindersSyncPlanner.plan(
            direction: .toHomeAssistant,
            todoItems: [:],
            reminders: ["reminder-1": item],
            links: [link(snapshot: item)]
        )
        #expect(operations == [.createTodoItem(reminderId: "reminder-1")])
    }

    @Test func testLinkWhoseItemsAreGoneOnBothSidesIsRemoved() {
        for direction in RemindersSyncDirection.allCases {
            let operations = RemindersSyncPlanner.plan(
                direction: direction,
                todoItems: [:],
                reminders: [:],
                links: [link(snapshot: snapshot())]
            )
            #expect(operations == [.deleteLink(todoItemUid: "todo-1")])
        }
    }
}
