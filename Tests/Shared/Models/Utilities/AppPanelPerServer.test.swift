import Foundation
import GRDB
import HAKit
@testable import Shared
import XCTest

final class AppPanelPerServerTests: XCTestCase {
    private var previousServers: ServerManager!
    private var previousDatabase: (() -> DatabaseQueue)!
    private var servers: FakeServerManager!
    private var database: DatabaseQueue!

    override func setUpWithError() throws {
        try super.setUpWithError()
        previousServers = Current.servers
        previousDatabase = Current.database

        let queue = try DatabaseQueue()
        try AppPanelTable().createIfNeeded(database: queue)
        database = queue
        Current.database = { queue }

        servers = FakeServerManager()
        Current.servers = servers
    }

    override func tearDown() {
        Current.servers = previousServers
        Current.database = previousDatabase
        super.tearDown()
    }

    private func insert(_ panels: [AppPanel]) throws {
        try database.write { db in
            for panel in panels {
                try panel.insert(db)
            }
        }
    }

    func testPanelsAreFilteredByServer() throws {
        try insert([
            AppPanel(serverId: "a", title: "Overview", path: "lovelace", component: "lovelace", showInSidebar: true),
            AppPanel(serverId: "b", title: "Energy", path: "energy", component: "energy", showInSidebar: true),
        ])

        XCTAssertEqual(try AppPanel.panels(serverId: "a")?.map(\.path), ["lovelace"])
        XCTAssertEqual(try AppPanel.panels(serverId: "c")?.count, 0)
    }

    func testPanelsPerServerOnlyIncludesServersWithPanels() throws {
        let withPanels = servers.addFake()
        _ = servers.addFake()
        try insert([
            AppPanel(
                serverId: withPanels.identifier.rawValue,
                title: "Map",
                path: "map",
                component: "map",
                showInSidebar: false
            ),
        ])

        let result = try AppPanel.panelsPerServer()

        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[withPanels]?.map(\.path), ["map"])
    }

    func testPanelResponseDecodes() throws {
        let response = try HAPanelResponse(data: HAData(value: [
            "component_name": "lovelace",
            "icon": "mdi:home",
            "title": "Home",
            "config": "cfg",
            "url_path": "home",
        ]))

        XCTAssertEqual(response.componentName, "lovelace")
        XCTAssertEqual(response.icon, "mdi:home")
        XCTAssertEqual(response.title, "Home")
        XCTAssertEqual(response.config, "cfg")
        XCTAssertEqual(response.urlPath, "home")
    }
}
