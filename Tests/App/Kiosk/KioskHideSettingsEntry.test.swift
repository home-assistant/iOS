import GRDB
@testable import HomeAssistant
@testable import Shared
import SwiftUI
import Testing

@MainActor
@Suite(.serialized)
struct KioskHideSettingsEntryTests {
    @Test func switchingOnAsksBeforeStoringIt() throws {
        try withKioskDatabase { _ in
            let viewModel = KioskSettingsViewModel()

            viewModel.settingsEntryHiddenDidChange(true)

            // Nothing is hidden yet: the user has to acknowledge the alert first, so a stray tap can't
            // make the only way back into these settings disappear.
            #expect(viewModel.isShowingHideSettingsEntryConfirmation)
            #expect(!viewModel.settings.settingsEntryHidden)
        }
    }

    @Test func confirmingHidesTheEntry() throws {
        try withKioskDatabase { _ in
            let viewModel = KioskSettingsViewModel()

            viewModel.settingsEntryHiddenDidChange(true)
            viewModel.confirmHidingSettingsEntry()

            #expect(viewModel.settings.settingsEntryHidden)
        }
    }

    @Test func switchingOffNeedsNoConfirmation() throws {
        try withKioskDatabase { _ in
            let viewModel = KioskSettingsViewModel()
            viewModel.confirmHidingSettingsEntry()

            viewModel.settingsEntryHiddenDidChange(false)

            #expect(!viewModel.settings.settingsEntryHidden)
            #expect(!viewModel.isShowingHideSettingsEntryConfirmation)
        }
    }

    @Test func hiddenEntryIsPersisted() throws {
        try withKioskDatabase { database in
            let viewModel = KioskSettingsViewModel()

            viewModel.confirmHidingSettingsEntry()
            #expect(viewModel.save())

            let stored = try database.read { db in try KioskSettings.fetchOne(db) }
            #expect(stored?.settingsEntryHidden == true)
        }
    }

    @Test func settingsScreenWithVisibleEntry() throws {
        try withKioskDatabase { _ in
            assertLightDarkSnapshots(
                of: NavigationView { KioskSettingsView() },
                drawHierarchyInKeyWindow: true
            )
        }
    }

    @Test func settingsScreenWithHiddenEntry() throws {
        try withKioskDatabase { database in
            try database.write { db in
                try KioskSettings(settingsEntryHidden: true).insert(db, onConflict: .replace)
            }

            assertLightDarkSnapshots(
                of: NavigationView { KioskSettingsView() },
                drawHierarchyInKeyWindow: true
            )
        }
    }

    private func withKioskDatabase(_ body: (DatabaseQueue) throws -> Void) throws {
        let database = try DatabaseQueue()
        try KioskSettingsTable().createIfNeeded(database: database)
        let previousDatabase = Current.database
        let previousServers = Current.servers
        defer {
            Current.database = previousDatabase
            Current.servers = previousServers
        }
        Current.database = { database }
        Current.servers = FakeServerManager(initial: 1)

        try body(database)
    }
}
