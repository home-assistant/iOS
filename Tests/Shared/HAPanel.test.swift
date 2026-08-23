import Foundation
import GRDB
import HAKit
@testable import Shared
import Testing

struct HAPanelTests {
    @Test func includesDashboardsHiddenFromTheSidebar() throws {
        let data = HAData(value: [
            "lovelace": [
                "component_name": "lovelace",
                "icon": "mdi:view-dashboard",
                "title": "Overview",
                "url_path": "lovelace",
                "show_in_sidebar": true,
            ],
            "tablet": [
                "component_name": "lovelace",
                "icon": "mdi:tablet",
                "title": "Tablet",
                "url_path": "tablet",
                "show_in_sidebar": false,
            ],
            "_my": [
                "component_name": "my",
                "title": "My",
                "url_path": "_my",
                "show_in_sidebar": false,
            ],
        ])

        let panels = try HAPanels(data: data)

        #expect(panels.panelsByPath["lovelace"] != nil)
        let tablet = try #require(panels.panelsByPath["tablet"])
        #expect(tablet.title == "Tablet")
        #expect(tablet.path == "tablet")
        #expect(tablet.showInSidebar == false)
        #expect(panels.panelsByPath["_my"] == nil)
        #expect(panels.allPanels.contains(where: { $0.path == "tablet" }))
    }

    @Test func hiddenDashboardWithoutTitleUsesPath() throws {
        let data = HAData(value: [
            "lovelace-hidden": [
                "component_name": "lovelace",
                "title": NSNull(),
                "url_path": "lovelace-hidden",
                "show_in_sidebar": false,
            ] as [String: Any],
        ])

        let panels = try HAPanels(data: data)
        let hidden = try #require(panels.panelsByPath["lovelace-hidden"])
        #expect(hidden.title == "lovelace-hidden")
        #expect(hidden.showInSidebar == false)
    }

    @Test func panelsQueryReturnsHiddenDashboards() throws {
        let previousDatabase = Current.database
        let database = try DatabaseQueue(path: ":memory:")
        try AppPanelTable().createIfNeeded(database: database)
        Current.database = { database }
        defer { Current.database = previousDatabase }

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

        let panels = try AppPanel.panels(serverId: "server-1") ?? []
        #expect(Set(panels.map(\.path)) == Set(["lovelace", "tablet"]))
    }
}
