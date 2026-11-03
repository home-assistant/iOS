import Foundation
import GRDB
@testable import HomeAssistant
@testable import Shared
import SharedTesting
import SwiftUI
import Testing
import UIKit

/// The Reminders sync settings and their screens' models: preferences round-trip through the app
/// group defaults, saved pairings load and delete, the add form validates its selection, and the
/// history log renders its runs. None of these ask for Reminders access.
///
/// `.sharedState`: the tests write the app group defaults, swap `Current.database` and drive the
/// `RemindersSyncManager` singleton.
@Suite(.sharedState)
@MainActor
struct RemindersSyncSettingsViewModelTests {
    private static let defaultsKey = "remindersSyncSettings"

    /// Restores the stored settings (or their absence) after `body`.
    private func preservingSettings(_ body: () async throws -> Void) async rethrows {
        let defaults = UserDefaults(suiteName: AppConstants.AppGroupID) ?? .standard
        let previous = defaults.data(forKey: Self.defaultsKey)
        defer {
            if let previous {
                defaults.set(previous, forKey: Self.defaultsKey)
            } else {
                defaults.removeObject(forKey: Self.defaultsKey)
            }
        }
        try await body()
    }

    private func config(_ id: String, lastSync: Date? = nil) -> RemindersSyncConfig {
        RemindersSyncConfig(
            id: id,
            serverId: "server",
            todoEntityId: "todo.\(id)",
            todoEntityName: "List \(id)",
            reminderListId: "list-\(id)",
            reminderListName: "Reminders \(id)",
            direction: .bothWays,
            lastSyncDate: lastSync
        )
    }

    // MARK: - Settings

    @Test func settingsRoundTripThroughTheAppGroupDefaults() async throws {
        try await preservingSettings {
            let defaults = UserDefaults(suiteName: AppConstants.AppGroupID) ?? .standard
            defaults.removeObject(forKey: Self.defaultsKey)
            #expect(RemindersSyncSettings.current == RemindersSyncSettings())

            defaults.set(Data("not json".utf8), forKey: Self.defaultsKey)
            #expect(RemindersSyncSettings.current == RemindersSyncSettings())

            var settings = RemindersSyncSettings()
            settings.foregroundRefreshInterval = 60
            settings.conflictResolution = .reminders
            settings.save()
            #expect(RemindersSyncSettings.current == settings)
        }
    }

    @Test func intervalsHaveReadableLabels() {
        #expect(RemindersSyncSettings.intervalLabel(0) == L10n.RemindersSync.Settings.Refresh.off)
        for interval in RemindersSyncSettings.foregroundIntervalOptions + RemindersSyncSettings
            .backgroundIntervalOptions {
            #expect(!RemindersSyncSettings.intervalLabel(interval).isEmpty)
        }
        #expect(RemindersSyncSettings.foregroundIntervalOptions.first == 0)
        #expect(RemindersSyncSettings.backgroundIntervalOptions.last == TimeInterval(86400))
    }

    // MARK: - Settings screen model

    @Test func loadsSavesAndDeletesPairings() async throws {
        try await preservingSettings {
            try await SettingsTestDatabase.with({ db in
                try config("a", lastSync: Date(timeIntervalSince1970: 1_700_000_000)).insert(db)
                try config("b").insert(db)
            }) { database in
                let viewModel = RemindersSyncSettingsViewModel()
                viewModel.load()
                #expect(Set(viewModel.configs.map(\.id)) == ["a", "b"])
                #expect(viewModel.authorizationState == RemindersSyncManager.shared.authorizationState)

                // Background refresh stays off: submitting a refresh request crashes a test host,
                // where `RemindersSyncBackgroundRefresher.register()` never ran.
                viewModel.settings.backgroundRefreshInterval = 0
                viewModel.settings.foregroundRefreshInterval = 0
                viewModel.settings.conflictResolution = .reminders
                viewModel.saveSettings()
                #expect(RemindersSyncSettings.current.conflictResolution == .reminders)

                let first = try #require(viewModel.configs.first { $0.id == "a" })
                viewModel.delete(first)
                #expect(viewModel.configs.map(\.id) == ["b"])
                let stored = try await database.read { try RemindersSyncConfig.fetchAll($0) }
                #expect(stored.map(\.id) == ["b"])

                viewModel.syncNow()
            }
        }
    }

    // MARK: - Add form

    @Test func theAddFormNeedsACompleteSelectionBeforeSaving() async throws {
        let previousServers = Current.servers
        Current.servers = FakeServerManager(initial: 0)
        defer { Current.servers = previousServers }

        let viewModel = RemindersSyncAddViewModel()
        #expect(viewModel.servers.isEmpty)
        #expect(viewModel.todoEntities.isEmpty)
        #expect(!viewModel.hasTodoLists)
        #expect(!viewModel.isDuplicate)
        #expect(!viewModel.canSave)
        #expect(!viewModel.save())

        viewModel.selectedServerId = "server"
        viewModel.selectedTodoEntityId = "todo.missing"
        viewModel.selectedReminderListId = "list"
        // Selected ids that don't resolve to a list still can't be saved.
        #expect(viewModel.canSave)
        #expect(!viewModel.save())

        viewModel.selectedServerChanged()
        #expect(viewModel.selectedTodoEntityId == nil)
        viewModel.direction = .toReminders
        viewModel.reloadServers()
        #expect(!viewModel.hasLoaded)
    }

    // MARK: - History

    @Test(arguments: [false, true])
    func historyRendersWithAndWithoutRuns(_ withRuns: Bool) async throws {
        try await SettingsTestDatabase.with({ db in
            guard withRuns else { return }
            try RemindersSyncHistoryEntry(
                id: "ok",
                configId: "a",
                listLabel: "Groceries ↔ Shopping",
                date: Date(timeIntervalSince1970: 1_700_000_000),
                success: true,
                error: nil,
                details: "Created Milk\nUpdated Bread"
            ).insert(db)
            try RemindersSyncHistoryEntry(
                id: "failed",
                configId: "a",
                listLabel: "Groceries ↔ Shopping",
                date: Date(timeIntervalSince1970: 1_700_000_100),
                success: false,
                error: "The server is unreachable",
                details: ""
            ).insert(db)
        }) { _ in
            let driver = await SwiftUIScreenDriver.show(RemindersSyncHistoryView())
            defer { driver.close() }
            if withRuns {
                await #expect(driver.waitUntil { driver.rows.count >= 2 })
            } else {
                await #expect(driver.waitUntil { driver.rows.count == 1 })
            }
        }
    }
}
