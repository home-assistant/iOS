import Foundation
import GRDB
@testable import Shared
import SharedTesting
import Testing

/// The `Current.database()`-backed queries of the Reminders sync records, against an in-memory
/// database per test.
@Suite(.isolatedEnvironment)
struct RemindersSyncStoreTests {
    private func installDatabase(tables: Bool = true) throws {
        let database = try DatabaseQueue()
        if tables {
            try database.createSchemaWithPrivateDefaults()
        }
        Current.database = { database }
    }

    private func config(_ id: String, name: String) -> RemindersSyncConfig {
        RemindersSyncConfig(
            id: id,
            serverId: "server",
            todoEntityId: "todo.\(id)",
            todoEntityName: name,
            reminderListId: "list-\(id)",
            reminderListName: "List \(id)",
            direction: .bothWays
        )
    }

    private func link(config: String, uid: String) -> RemindersSyncItemLink {
        RemindersSyncItemLink(
            configId: config,
            todoItemUid: uid,
            reminderId: "reminder-\(uid)",
            lastKnownTitle: "Title \(uid)",
            lastKnownCompleted: false,
            lastKnownNotes: nil,
            lastKnownDue: nil
        )
    }

    @Test func configsSaveSortAndDeleteWithTheirLinks() throws {
        try installDatabase()
        config("b", name: "Shopping").save()
        config("a", name: "Chores").save()
        #expect(RemindersSyncConfig.all().map(\.id) == ["a", "b"])

        link(config: "a", uid: "1").save()
        link(config: "a", uid: "2").save()
        link(config: "b", uid: "3").save()
        #expect(RemindersSyncItemLink.links(configId: "a").count == 2)

        RemindersSyncItemLink.delete(configId: "a", todoItemUid: "1")
        #expect(RemindersSyncItemLink.links(configId: "a").map(\.todoItemUid) == ["2"])

        config("a", name: "Chores").delete()
        #expect(RemindersSyncConfig.all().map(\.id) == ["b"])
        #expect(RemindersSyncItemLink.links(configId: "a").isEmpty)
        #expect(RemindersSyncItemLink.links(configId: "b").count == 1)
    }

    @Test func historyIsNewestFirstAndCapped() throws {
        try installDatabase()
        let start = Date(timeIntervalSince1970: 1_780_000_000)
        for index in 0 ..< RemindersSyncHistoryEntry.maxStoredEntries + 3 {
            RemindersSyncHistoryEntry(
                id: "entry-\(index)",
                configId: "a",
                listLabel: "Chores",
                date: start.addingTimeInterval(TimeInterval(index)),
                success: index % 2 == 0,
                error: index % 2 == 0 ? nil : "failed",
                details: "run \(index)"
            ).save()
        }
        let entries = RemindersSyncHistoryEntry.all()
        #expect(entries.count == RemindersSyncHistoryEntry.maxStoredEntries)
        #expect(entries.first?.id == "entry-\(RemindersSyncHistoryEntry.maxStoredEntries + 2)")
        #expect(!entries.contains { $0.id == "entry-0" })

        RemindersSyncHistoryEntry.deleteAll()
        #expect(RemindersSyncHistoryEntry.all().isEmpty)
    }

    @Test func failuresReadAsEmptyAndAreLogged() throws {
        try installDatabase(tables: false)
        #expect(RemindersSyncConfig.all().isEmpty)
        #expect(RemindersSyncItemLink.links(configId: "a").isEmpty)
        #expect(RemindersSyncHistoryEntry.all().isEmpty)
        config("a", name: "x").save()
        config("a", name: "x").delete()
        link(config: "a", uid: "1").save()
        RemindersSyncItemLink.delete(configId: "a", todoItemUid: "1")
        RemindersSyncHistoryEntry(
            id: "e", configId: "a", listLabel: "x", date: Date(), success: true, error: nil, details: ""
        ).save()
        RemindersSyncHistoryEntry.deleteAll()
        #expect(RemindersSyncConfig.all().isEmpty)
    }
}
