import Foundation
import GRDB
@testable import Shared
import SharedTesting
import Testing

/// Panels grouped per configured server, read through `Current` on the test's task.
@Suite(.isolatedEnvironment)
struct AppPanelQueriesTests {
    @Test func panelsAreGroupedPerServerWithPanels() throws {
        let database = try DatabaseQueue()
        try database.createSchemaWithPrivateDefaults()
        Current.database = { database }
        let servers = FakeServerManager(initial: 2)
        Current.servers = servers
        let first = servers.all[0]
        try database.write { db in
            try AppPanel(
                serverId: first.identifier.rawValue,
                title: "Energy",
                path: "energy",
                component: "energy",
                showInSidebar: true
            ).insert(db)
        }

        let grouped = try AppPanel.panelsPerServer()
        #expect(grouped.count == 1)
        #expect(grouped[first]?.map(\.title) == ["Energy"])
        // swiftformat:disable:next hoistTry
        #expect(try AppPanel.panels(serverId: servers.all[1].identifier.rawValue)?.isEmpty == true)
    }

    @Test func failingServersAreSkipped() throws {
        let database = try DatabaseQueue()
        Current.database = { database }
        Current.servers = FakeServerManager(initial: 1)
        // swiftformat:disable:next hoistTry
        #expect(try AppPanel.panelsPerServer().isEmpty)
    }
}
