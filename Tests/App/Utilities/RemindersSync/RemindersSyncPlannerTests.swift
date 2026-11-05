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

    @Test func testUnlinkedItemsWhoseTitlesDifferOnlyInCaseAreAdopted() {
        let operations = RemindersSyncPlanner.plan(
            direction: .bothWays,
            todoItems: ["todo-1": snapshot(title: "Almond milk")],
            reminders: ["reminder-1": snapshot(title: "Almond Milk")],
            links: []
        )
        #expect(operations == [
            .adoptLink(todoItemUid: "todo-1", reminderId: "reminder-1"),
            .updateReminder(todoItemUid: "todo-1", reminderId: "reminder-1"),
        ])
    }

    @Test func testExactTitleIsAdoptedBeforeOneDifferingOnlyInCase() {
        let operations = RemindersSyncPlanner.plan(
            direction: .bothWays,
            todoItems: ["todo-1": snapshot(title: "Almond milk")],
            reminders: [
                "reminder-1": snapshot(title: "ALMOND MILK"),
                "reminder-2": snapshot(title: "Almond milk"),
            ],
            links: []
        )
        #expect(operations == [
            .adoptLink(todoItemUid: "todo-1", reminderId: "reminder-2"),
            .createTodoItem(reminderId: "reminder-1"),
        ])
    }

    @Test func testAdoptedPairWithDifferentContentIsAlignedPerDirection() {
        let todoItems = ["todo-1": snapshot(notes: "bring the tote bag")]
        let reminders = ["reminder-1": snapshot(notes: nil)]

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

    @Test func testConflictingEditsResolveInFavorOfHomeAssistantByDefault() {
        let operations = RemindersSyncPlanner.plan(
            direction: .bothWays,
            todoItems: ["todo-1": snapshot(title: "HA edit")],
            reminders: ["reminder-1": snapshot(title: "Reminders edit")],
            links: [link(snapshot: snapshot())]
        )
        #expect(operations == [.updateReminder(todoItemUid: "todo-1", reminderId: "reminder-1")])
    }

    @Test func testConflictingEditsCanResolveInFavorOfReminders() {
        let operations = RemindersSyncPlanner.plan(
            direction: .bothWays,
            conflictResolution: .reminders,
            todoItems: ["todo-1": snapshot(title: "HA edit")],
            reminders: ["reminder-1": snapshot(title: "Reminders edit")],
            links: [link(snapshot: snapshot())]
        )
        #expect(operations == [.updateTodoItem(todoItemUid: "todo-1", reminderId: "reminder-1")])
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

    @Test func testCompletingAReminderTheListReCasedIsNotUndoneWhenSyncingBothWays() {
        let written = snapshot(title: "Almond Milk")
        let operations = RemindersSyncPlanner.plan(
            direction: .bothWays,
            todoItems: ["todo-1": snapshot(title: "Almond milk")],
            reminders: ["reminder-1": snapshot(title: "Almond Milk", isCompleted: true)],
            links: [link(snapshot: written)]
        )
        #expect(operations == [.updateTodoItem(todoItemUid: "todo-1", reminderId: "reminder-1")])
    }

    @Test func testCaseOnlyTodoItemEditStillPropagatesWhenSyncingBothWays() {
        let original = snapshot(title: "Almond milk")
        let operations = RemindersSyncPlanner.plan(
            direction: .bothWays,
            todoItems: ["todo-1": snapshot(title: "Almond Milk")],
            reminders: ["reminder-1": original],
            links: [link(snapshot: original)]
        )
        #expect(operations == [.updateReminder(todoItemUid: "todo-1", reminderId: "reminder-1")])
    }

    @Test func testSyncingToHomeAssistantAcceptsTheListReCasingTheWrittenTitle() {
        let written = snapshot(title: "Almond Milk")
        let operations = RemindersSyncPlanner.plan(
            direction: .toHomeAssistant,
            todoItems: ["todo-1": snapshot(title: "Almond milk")],
            reminders: ["reminder-1": written],
            links: [link(snapshot: written)]
        )
        #expect(operations.isEmpty)
    }

    @Test func testSyncingToHomeAssistantStillPushesACaseOnlyReminderEdit() {
        let operations = RemindersSyncPlanner.plan(
            direction: .toHomeAssistant,
            todoItems: ["todo-1": snapshot(title: "Almond milk")],
            reminders: ["reminder-1": snapshot(title: "Almond Milk")],
            links: [link(snapshot: snapshot(title: "Almond milk"))]
        )
        #expect(operations == [.updateTodoItem(todoItemUid: "todo-1", reminderId: "reminder-1")])
    }

    // MARK: - Completed items

    @Test func testUnlinkedCompletedItemsAreNeverSynced() {
        let completed = snapshot(isCompleted: true)
        for direction in RemindersSyncDirection.allCases {
            let operations = RemindersSyncPlanner.plan(
                direction: direction,
                todoItems: ["todo-1": completed],
                reminders: ["reminder-1": snapshot(title: "Other completed", isCompleted: true)],
                links: []
            )
            #expect(operations.isEmpty)
        }
    }

    @Test func testUnlinkedCompletedItemsAreNotAdoptedByTitle() {
        // Same title on both sides, but completed: leave both alone instead of linking them.
        let completed = snapshot(isCompleted: true)
        let operations = RemindersSyncPlanner.plan(
            direction: .bothWays,
            todoItems: ["todo-1": completed],
            reminders: ["reminder-1": completed],
            links: []
        )
        #expect(operations.isEmpty)
    }

    @Test func testIncludingCompletedItemsCreatesThemOnTheOtherSide() {
        let completedItem = snapshot(title: "Done in HA", isCompleted: true)
        let completedReminder = snapshot(title: "Done in Reminders", isCompleted: true)
        let inputs = (todoItems: ["todo-1": completedItem], reminders: ["reminder-1": completedReminder])

        let bothWays = RemindersSyncPlanner.plan(
            direction: .bothWays,
            includeCompletedItems: true,
            todoItems: inputs.todoItems,
            reminders: inputs.reminders,
            links: []
        )
        #expect(bothWays == [.createReminder(todoItemUid: "todo-1"), .createTodoItem(reminderId: "reminder-1")])

        let toReminders = RemindersSyncPlanner.plan(
            direction: .toReminders,
            includeCompletedItems: true,
            todoItems: inputs.todoItems,
            reminders: inputs.reminders,
            links: []
        )
        #expect(toReminders == [.createReminder(todoItemUid: "todo-1")])

        let toHomeAssistant = RemindersSyncPlanner.plan(
            direction: .toHomeAssistant,
            includeCompletedItems: true,
            todoItems: inputs.todoItems,
            reminders: inputs.reminders,
            links: []
        )
        #expect(toHomeAssistant == [.createTodoItem(reminderId: "reminder-1")])
    }

    @Test func testIncludingCompletedItemsAdoptsSameTitledCompletedPairs() {
        let completed = snapshot(isCompleted: true)
        let operations = RemindersSyncPlanner.plan(
            direction: .bothWays,
            includeCompletedItems: true,
            todoItems: ["todo-1": completed],
            reminders: ["reminder-1": completed],
            links: []
        )
        #expect(operations == [.adoptLink(todoItemUid: "todo-1", reminderId: "reminder-1")])
    }

    @Test func testIncludingCompletedItemsPrefersAdoptingTheSameCompletionState() {
        // An open item and a checked-off copy of the same title on the other side: pair the open
        // ones together and mirror the completed one, rather than pairing open with completed.
        let open = snapshot()
        let completed = snapshot(isCompleted: true)
        let operations = RemindersSyncPlanner.plan(
            direction: .bothWays,
            includeCompletedItems: true,
            todoItems: ["todo-1": open],
            reminders: ["reminder-completed": completed, "reminder-open": open],
            links: []
        )
        #expect(operations == [
            .adoptLink(todoItemUid: "todo-1", reminderId: "reminder-open"),
            .createTodoItem(reminderId: "reminder-completed"),
        ])
    }

    @Test func testIncludingCompletedItemsMatchesAllSameStatePairsBeforeCrossStateOnes() {
        // The completed item sorts first, but must not take the only open reminder away from the
        // open item that matches it exactly.
        let open = snapshot()
        let completed = snapshot(isCompleted: true)
        let operations = RemindersSyncPlanner.plan(
            direction: .bothWays,
            includeCompletedItems: true,
            todoItems: ["a-completed": completed, "z-open": open],
            reminders: ["reminder-open": open],
            links: []
        )
        #expect(operations == [
            .adoptLink(todoItemUid: "z-open", reminderId: "reminder-open"),
            .createReminder(todoItemUid: "a-completed"),
        ])
    }

    @Test func testIncludingCompletedItemsReopensAnAdoptedCompletedCopy() {
        // Only a completed copy of a newly added open item exists on the other side: with
        // Home Assistant winning, link them and reopen the reminder instead of creating a
        // duplicate.
        let open = snapshot()
        let completed = snapshot(isCompleted: true)
        let operations = RemindersSyncPlanner.plan(
            direction: .bothWays,
            includeCompletedItems: true,
            todoItems: ["todo-1": open],
            reminders: ["reminder-1": completed],
            links: []
        )
        #expect(operations == [
            .adoptLink(todoItemUid: "todo-1", reminderId: "reminder-1"),
            .updateReminder(todoItemUid: "todo-1", reminderId: "reminder-1"),
        ])
    }

    @Test func testCompletingALinkedReminderCompletesTheTodoItem() {
        let original = snapshot()
        let operations = RemindersSyncPlanner.plan(
            direction: .bothWays,
            todoItems: ["todo-1": original],
            reminders: ["reminder-1": snapshot(isCompleted: true)],
            links: [link(snapshot: original)]
        )
        #expect(operations == [.updateTodoItem(todoItemUid: "todo-1", reminderId: "reminder-1")])
    }

    @Test func testOneWayRestoreDropsTheLinkForCompletedItems() {
        let completed = snapshot(isCompleted: true)

        // Completed reminder whose HA item is gone: don't resurrect it in HA.
        let toHomeAssistant = RemindersSyncPlanner.plan(
            direction: .toHomeAssistant,
            todoItems: [:],
            reminders: ["reminder-1": completed],
            links: [link(snapshot: completed)]
        )
        #expect(toHomeAssistant == [.deleteLink(todoItemUid: "todo-1")])

        // Completed HA item whose reminder is gone: don't resurrect it in Reminders.
        let toReminders = RemindersSyncPlanner.plan(
            direction: .toReminders,
            todoItems: ["todo-1": completed],
            reminders: [:],
            links: [link(snapshot: completed)]
        )
        #expect(toReminders == [.deleteLink(todoItemUid: "todo-1")])
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
