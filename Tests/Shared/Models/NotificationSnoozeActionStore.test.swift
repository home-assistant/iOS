import Foundation
import GRDB
@testable import Shared
import SharedTesting
import Testing

/// Snooze presets: their titles and the database-backed store. Reads `Current.database()` on the
/// test's task, so each test gets its own environment and in-memory database.
@Suite(.isolatedEnvironment)
struct NotificationSnoozeActionStoreTests {
    /// The watch mirror pushes the store requested. Bound through `WatchMirrorPushCoordinator.scheduleOverride`
    /// for the test's task, so a mutation never leaves a debounced, process-wide push behind that would run
    /// after this test against whatever `Current` is global by then.
    private final class MirrorPushes: @unchecked Sendable {
        private let lock = NSLock()
        private var storage: [WatchMirrorPushCoordinator.Reason] = []

        func record(_ reason: WatchMirrorPushCoordinator.Reason) {
            lock.lock(); defer { lock.unlock() }
            storage.append(reason)
        }

        var all: [WatchMirrorPushCoordinator.Reason] {
            lock.lock(); defer { lock.unlock() }
            return storage
        }
    }

    private func recordingMirrorPushes(_ body: (MirrorPushes) throws -> Void) throws {
        let pushes = MirrorPushes()
        try WatchMirrorPushCoordinator.$scheduleOverride.withValue({ pushes.record($0) }) {
            try body(pushes)
        }
    }

    private func installDatabase() throws -> DatabaseQueue {
        let database = try DatabaseQueue()
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        Current.database = { database }
        return database
    }

    @Test func titlesCoverMinutesHoursAndMixes() {
        let titles = [5, 60, 120, 90, 150].map { NotificationSnoozeAction(minutes: $0, sortOrder: 0).title }
        #expect(titles.allSatisfy { !$0.isEmpty })
        #expect(Set(titles).count == titles.count)
        let action = NotificationSnoozeAction(minutes: 15, sortOrder: 0).action
        #expect(action.identifier.hasSuffix("15"))
        #expect(action.title == NotificationSnoozeAction(minutes: 15, sortOrder: 0).title)
    }

    @Test func storeSeedsSavesReordersAndDeletes() throws {
        try recordingMirrorPushes { pushes in
            try seedSaveReorderAndDelete()
            #expect(pushes.all == Array(repeating: .notificationSnoozeActionsChanged, count: 4))
        }
    }

    private func seedSaveReorderAndDelete() throws {
        let database = try installDatabase()
        try database.write { db in try NotificationSnoozeAction.deleteAll(db) }
        try NotificationSnoozeAction.seedDefaultsIfNeeded(database: database)
        #expect(NotificationSnoozeAction.all().map(\.minutes) == [5, 15, 60])

        var disabled = NotificationSnoozeAction(minutes: 30, isEnabled: false, sortOrder: 3)
        NotificationSnoozeAction.save(disabled)
        #expect(NotificationSnoozeAction.all().count == 4)
        let enabledMinutes = NotificationSnoozeAction.enabledActions().compactMap {
            NotificationSnoozeAction.minutes(fromActionIdentifier: $0.identifier)
        }
        #expect(!enabledMinutes.contains(30))

        disabled.isEnabled = true
        NotificationSnoozeAction.save(disabled)
        #expect(NotificationSnoozeAction.all().first { $0.minutes == 30 }?.isEnabled == true)

        let ids = NotificationSnoozeAction.all().map(\.id)
        NotificationSnoozeAction.reorder(ids.reversed())
        #expect(NotificationSnoozeAction.all().map(\.minutes) == [30, 60, 15, 5])

        NotificationSnoozeAction.delete(id: disabled.id)
        #expect(NotificationSnoozeAction.all().map(\.minutes) == [60, 15, 5])
    }

    @Test func storeFailuresReadAsEmpty() throws {
        let database = try DatabaseQueue()
        Current.database = { database }
        try recordingMirrorPushes { pushes in
            #expect(NotificationSnoozeAction.all().isEmpty)
            NotificationSnoozeAction.save(NotificationSnoozeAction(minutes: 5, sortOrder: 0))
            NotificationSnoozeAction.delete(id: "missing")
            NotificationSnoozeAction.reorder(["missing"])
            #expect(NotificationSnoozeAction.all().isEmpty)
            // A write that failed has nothing new for the watch.
            #expect(pushes.all.isEmpty)
        }
    }
}
