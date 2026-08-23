import Foundation
import GRDB
@testable import HomeAssistant
@testable import Shared
import Testing

@MainActor
struct KioskSettingsViewModelTests {
    @Test func reloadPanelsIncludesDashboardsHiddenFromTheSidebar() throws {
        let previousDatabase = Current.database
        let previousServers = Current.servers
        let database = try DatabaseQueue(path: ":memory:")
        try KioskSettingsTable().createIfNeeded(database: database)
        try AppPanelTable().createIfNeeded(database: database)
        Current.database = { database }
        let servers = FakeServerManager()
        _ = servers.add(identifier: .init(rawValue: "server-1"), serverInfo: .fake())
        Current.servers = servers
        defer {
            Current.database = previousDatabase
            Current.servers = previousServers
        }

        try database.write { db in
            try AppPanel(
                serverId: "server-1",
                title: "Overview",
                path: "lovelace",
                component: "lovelace",
                showInSidebar: true
            ).insert(db)
            try AppPanel(
                serverId: "server-1",
                title: "Tablet",
                path: "tablet",
                component: "lovelace",
                showInSidebar: false
            ).insert(db)
        }

        let viewModel = KioskSettingsViewModel()
        viewModel.settings.serverId = "server-1"
        viewModel.reloadPanels()

        let paths = viewModel.panels.map(\.path)
        #expect(paths.contains("lovelace"))
        #expect(paths.contains("tablet"))
        #expect(viewModel.panels.first(where: { $0.path == "tablet" })?.showInSidebar == false)
    }
}
