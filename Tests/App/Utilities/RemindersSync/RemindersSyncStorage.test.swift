import GRDB
@testable import HomeAssistant
import SFSafeSymbols
@testable import Shared
import SwiftUI
import UIKit
import XCTest

/// The Reminders sync configuration, links and history as stored in the app database, plus the
/// settings and screens that read them. Nothing here needs Reminders access.
@MainActor
final class RemindersSyncStorageTests: XCTestCase {
    private static let settingsKey = "remindersSyncSettings"

    private var previousDatabase: (() -> DatabaseQueue)!
    private var previousSettingsData: Data?
    private var appGroupDefaults: UserDefaults {
        UserDefaults(suiteName: AppConstants.AppGroupID) ?? .standard
    }

    override func setUpWithError() throws {
        try super.setUpWithError()
        previousDatabase = Current.database
        let database = try DatabaseQueue()
        for table in DatabaseQueue.tables() {
            try table.createIfNeeded(database: database)
        }
        Current.database = { database }

        previousSettingsData = appGroupDefaults.data(forKey: Self.settingsKey)
        appGroupDefaults.removeObject(forKey: Self.settingsKey)
    }

    override func tearDown() {
        Current.database = previousDatabase
        if let previousSettingsData {
            appGroupDefaults.set(previousSettingsData, forKey: Self.settingsKey)
        } else {
            appGroupDefaults.removeObject(forKey: Self.settingsKey)
        }
        super.tearDown()
    }

    // MARK: - Configs

    func testConfigsAreSortedByListNameAndReplacedOnSave() {
        XCTAssertTrue(RemindersSyncConfig.all().isEmpty)

        config(id: "b", todoEntityName: "Shopping").save()
        config(id: "a", todoEntityName: "Chores").save()
        XCTAssertEqual(RemindersSyncConfig.all().map(\.id), ["a", "b"])

        var renamed = config(id: "b", todoEntityName: "Aaa groceries")
        renamed.lastSyncDate = Date(timeIntervalSince1970: 1000)
        renamed.save()
        let all = RemindersSyncConfig.all()
        XCTAssertEqual(all.map(\.id), ["b", "a"])
        XCTAssertEqual(all.first?.lastSyncDate, Date(timeIntervalSince1970: 1000))
    }

    func testDeletingAConfigDeletesItsLinks() {
        let kept = config(id: "kept", todoEntityName: "Kept")
        let deleted = config(id: "deleted", todoEntityName: "Deleted")
        kept.save()
        deleted.save()
        link(configId: "kept", todoItemUid: "1").save()
        link(configId: "deleted", todoItemUid: "2").save()

        deleted.delete()

        XCTAssertEqual(RemindersSyncConfig.all().map(\.id), ["kept"])
        XCTAssertEqual(RemindersSyncItemLink.links(configId: "kept").map(\.todoItemUid), ["1"])
        XCTAssertTrue(RemindersSyncItemLink.links(configId: "deleted").isEmpty)
    }

    // MARK: - Links

    func testLinksAreKeyedByConfigAndItem() {
        link(configId: "c", todoItemUid: "1", title: "Milk").save()
        link(configId: "c", todoItemUid: "1", title: "Oat milk").save()
        link(configId: "c", todoItemUid: "2", title: "Bread").save()
        link(configId: "other", todoItemUid: "1", title: "Elsewhere").save()

        let links = RemindersSyncItemLink.links(configId: "c").sorted { $0.todoItemUid < $1.todoItemUid }
        XCTAssertEqual(links.map(\.lastKnownTitle), ["Oat milk", "Bread"])
        XCTAssertEqual(links.first?.id, RemindersSyncItemLink.id(configId: "c", todoItemUid: "1"))

        RemindersSyncItemLink.delete(configId: "c", todoItemUid: "1")
        XCTAssertEqual(RemindersSyncItemLink.links(configId: "c").map(\.todoItemUid), ["2"])
        XCTAssertEqual(RemindersSyncItemLink.links(configId: "other").count, 1)
    }

    // MARK: - History

    func testHistoryIsNewestFirstAndClearable() {
        historyEntry(id: "old", date: Date(timeIntervalSince1970: 100)).save()
        historyEntry(id: "new", date: Date(timeIntervalSince1970: 200)).save()

        XCTAssertEqual(RemindersSyncHistoryEntry.all().map(\.id), ["new", "old"])

        RemindersSyncHistoryEntry.deleteAll()
        XCTAssertTrue(RemindersSyncHistoryEntry.all().isEmpty)
    }

    func testHistoryIsCappedToItsNewestEntries() {
        let total = RemindersSyncHistoryEntry.maxStoredEntries + 2
        for index in 0 ..< total {
            historyEntry(id: "entry-\(index)", date: Date(timeIntervalSince1970: TimeInterval(index))).save()
        }

        let all = RemindersSyncHistoryEntry.all()
        XCTAssertEqual(all.count, RemindersSyncHistoryEntry.maxStoredEntries)
        XCTAssertEqual(all.first?.id, "entry-\(total - 1)")
        XCTAssertFalse(all.contains { $0.id == "entry-0" || $0.id == "entry-1" })
    }

    // MARK: - Settings

    func testSettingsDefaultWhenNothingIsStored() {
        let settings = RemindersSyncSettings.current
        XCTAssertEqual(settings, RemindersSyncSettings())
        XCTAssertEqual(settings.foregroundRefreshInterval, 0)
        XCTAssertEqual(settings.backgroundRefreshInterval, 0)
        XCTAssertEqual(settings.conflictResolution, .homeAssistant)
    }

    func testSettingsRoundTrip() {
        var settings = RemindersSyncSettings()
        settings.foregroundRefreshInterval = 0
        settings.backgroundRefreshInterval = 15 * 60
        settings.conflictResolution = .reminders
        settings.save()

        XCTAssertEqual(RemindersSyncSettings.current, settings)
    }

    func testCorruptSettingsFallBackToDefaults() {
        appGroupDefaults.set(Data("not json".utf8), forKey: Self.settingsKey)
        XCTAssertEqual(RemindersSyncSettings.current, RemindersSyncSettings())
    }

    func testIntervalLabels() {
        XCTAssertEqual(RemindersSyncSettings.intervalLabel(0), L10n.RemindersSync.Settings.Refresh.off)
        XCTAssertFalse(RemindersSyncSettings.intervalLabel(15 * 60).isEmpty)
        XCTAssertNotEqual(RemindersSyncSettings.intervalLabel(60 * 60), RemindersSyncSettings.intervalLabel(30 * 60))
        XCTAssertEqual(RemindersSyncSettings.foregroundIntervalOptions.first, 0)
        XCTAssertEqual(RemindersSyncSettings.backgroundIntervalOptions.first, 0)
    }

    func testDirectionAndConflictPresentation() {
        XCTAssertEqual(RemindersSyncDirection.bothWays.localizedTitle, L10n.RemindersSync.Direction.bothWays)
        XCTAssertEqual(
            RemindersSyncDirection.toHomeAssistant.localizedTitle,
            L10n.RemindersSync.Direction.toHomeAssistant
        )
        XCTAssertEqual(RemindersSyncDirection.toReminders.localizedTitle, L10n.RemindersSync.Direction.toReminders)
        XCTAssertEqual(RemindersSyncDirection.bothWays.symbol.rawValue, SFSymbol.arrowLeftArrowRight.rawValue)
        XCTAssertEqual(RemindersSyncDirection.toHomeAssistant.symbol.rawValue, SFSymbol.arrowRight.rawValue)
        XCTAssertEqual(RemindersSyncDirection.toReminders.symbol.rawValue, SFSymbol.arrowLeft.rawValue)

        XCTAssertEqual(RemindersSyncConflictResolution.homeAssistant.localizedTitle, L10n.RemindersSync.Conflict.homeAssistant)
        XCTAssertEqual(RemindersSyncConflictResolution.reminders.localizedTitle, L10n.RemindersSync.Conflict.reminders)
        XCTAssertEqual(RemindersSyncConflictResolution.allCases.map(\.id), ["homeAssistant", "reminders"])
    }

    // MARK: - Settings view model

    func testSettingsViewModelLoadsAndDeletesConfigs() {
        config(id: "a", todoEntityName: "Chores").save()
        config(id: "b", todoEntityName: "Shopping").save()
        let viewModel = RemindersSyncSettingsViewModel()

        viewModel.load()
        XCTAssertEqual(viewModel.configs.map(\.id), ["a", "b"])
        XCTAssertEqual(viewModel.authorizationState, RemindersSyncManager.shared.authorizationState)
        XCTAssertEqual(viewModel.settings, RemindersSyncSettings.current)

        viewModel.delete(viewModel.configs[0])
        XCTAssertEqual(viewModel.configs.map(\.id), ["b"])
    }

    func testSettingsViewModelSavesSettings() {
        let viewModel = RemindersSyncSettingsViewModel()
        viewModel.settings.conflictResolution = .reminders

        viewModel.saveSettings()

        XCTAssertEqual(RemindersSyncSettings.current.conflictResolution, .reminders)
    }

    // MARK: - Add view model

    func testAddViewModelCannotSaveWithoutASelection() {
        let viewModel = RemindersSyncAddViewModel()

        XCTAssertFalse(viewModel.hasTodoLists)
        XCTAssertTrue(viewModel.servers.isEmpty)
        XCTAssertTrue(viewModel.todoEntities.isEmpty)
        XCTAssertFalse(viewModel.isDuplicate)
        XCTAssertFalse(viewModel.canSave)
        XCTAssertFalse(viewModel.save())
        XCTAssertEqual(viewModel.direction, .bothWays)

        viewModel.selectedServerId = "server"
        viewModel.selectedTodoEntityId = "todo.shopping"
        viewModel.selectedServerChanged()
        XCTAssertNil(viewModel.selectedTodoEntityId, "the entity doesn't belong to the selected server")
    }

    // MARK: - Manager

    func testManagerDoesNotSyncWithoutAccess() async throws {
        let manager = RemindersSyncManager.shared
        try XCTSkipIf(manager.authorizationState == .authorized, "this simulator has granted Reminders access")
        config(id: "a", todoEntityName: "Chores").save()

        await manager.syncAll()

        XCTAssertFalse(manager.isSyncing)
        XCTAssertNil(RemindersSyncConfig.all().first?.lastSyncDate)
        manager.settingsChanged()
    }

    // MARK: - History screen

    func testHistoryScreenRendersItsEntries() {
        historyEntry(id: "ok", date: Date(timeIntervalSince1970: 100), details: "Created Milk\nUpdated Bread").save()
        historyEntry(id: "failed", date: Date(timeIntervalSince1970: 200), error: "Offline").save()

        XCTAssertGreaterThan(render(NavigationView { RemindersSyncHistoryView() }), 0)
    }

    func testHistoryScreenRendersWhenEmpty() {
        XCTAssertGreaterThan(render(NavigationView { RemindersSyncHistoryView() }), 0)
    }

    // MARK: - Helpers

    private func config(id: String, todoEntityName: String) -> RemindersSyncConfig {
        RemindersSyncConfig(
            id: id,
            serverId: "server",
            todoEntityId: "todo.\(id)",
            todoEntityName: todoEntityName,
            reminderListId: "list-\(id)",
            reminderListName: "List \(id)",
            direction: .bothWays
        )
    }

    private func link(configId: String, todoItemUid: String, title: String = "Item") -> RemindersSyncItemLink {
        RemindersSyncItemLink(
            configId: configId,
            todoItemUid: todoItemUid,
            reminderId: "reminder-\(todoItemUid)",
            lastKnownTitle: title,
            lastKnownCompleted: false,
            lastKnownNotes: nil,
            lastKnownDue: nil
        )
    }

    private func historyEntry(
        id: String,
        date: Date,
        error: String? = nil,
        details: String = ""
    ) -> RemindersSyncHistoryEntry {
        RemindersSyncHistoryEntry(
            id: id,
            configId: "config",
            listLabel: "List ↔ To-do",
            date: date,
            success: error == nil,
            error: error,
            details: details
        )
    }

    private func render(_ view: some View) -> CGFloat {
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        controller.view.layoutIfNeeded()
        let height = controller.sizeThatFits(in: CGSize(width: 390, height: 844)).height
        window.isHidden = true
        window.rootViewController = nil
        return height
    }
}
