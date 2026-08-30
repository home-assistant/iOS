import Foundation
import HAKit
@testable import Shared
import Testing

@Suite("HAPanels Tests")
struct HAPanelsTests {
    private func panel(
        component: String,
        urlPath: String,
        title: Any = NSNull(),
        showInSidebar: Bool? = nil,
        defaultVisible: Bool? = nil
    ) -> [String: Any] {
        var value: [String: Any] = [
            "component_name": component,
            "url_path": urlPath,
            "title": title,
            "icon": NSNull(),
        ]
        if let showInSidebar {
            value["show_in_sidebar"] = showInSidebar
        }
        if let defaultVisible {
            value["default_visible"] = defaultVisible
        }
        return value
    }

    @Test("Keeps dashboards that are hidden from the sidebar")
    func keepsDashboardsHiddenFromTheSidebar() throws {
        let panels = try HAPanels(data: HAData(value: [
            "lovelace": panel(component: "lovelace", urlPath: "lovelace", title: "Overview", showInSidebar: true),
            "hidden-dashboard": panel(
                component: "lovelace",
                urlPath: "hidden-dashboard",
                title: "Hidden",
                showInSidebar: false
            ),
        ]))

        #expect(panels.panelsByPath["hidden-dashboard"] != nil)
        #expect(panels.panelsByPath["hidden-dashboard"]?.showInSidebar == false)
        #expect(panels.allPanels.count == 2)
    }

    @Test("Keeps the built-in dashboards core registers outside the sidebar")
    func keepsBuiltInDashboards() throws {
        let panels = try HAPanels(data: HAData(value: [
            "home": panel(component: "home", urlPath: "home", title: "home", showInSidebar: false),
            "light": panel(component: "light", urlPath: "light", title: "light", showInSidebar: false),
            "security": panel(component: "security", urlPath: "security", title: "security", showInSidebar: false),
            "climate": panel(component: "climate", urlPath: "climate", title: "climate", showInSidebar: false),
            "maintenance": panel(
                component: "maintenance",
                urlPath: "maintenance",
                title: "maintenance",
                showInSidebar: false
            ),
        ]))

        #expect(panels.allPanels.count == 5)
        #expect(panels.allPanels.first?.path == "home")
    }

    @Test("Localizes the titles of the built-in dashboards")
    func localizesBuiltInDashboardTitles() throws {
        let panels = try HAPanels(data: HAData(value: [
            "home": panel(component: "home", urlPath: "home", title: "home", showInSidebar: false),
            "light": panel(component: "light", urlPath: "light", title: "light", showInSidebar: false),
        ]))

        #expect(panels.panelsByPath["home"]?.title == "Overview")
        #expect(panels.panelsByPath["light"]?.title == "Lights")
    }

    @Test("Skips panels the frontend never offers as a destination")
    func skipsSystemPanels() throws {
        let panels = try HAPanels(data: HAData(value: [
            "_my_redirect": panel(component: "my", urlPath: "_my_redirect"),
            "notfound": panel(component: "notfound", urlPath: "notfound"),
            "core_ssh": panel(component: "app", urlPath: "core_ssh", title: "Terminal"),
            "lovelace": panel(component: "lovelace", urlPath: "lovelace", title: "Overview"),
        ]))

        #expect(panels.allPanels.map(\.path) == ["lovelace"])
    }

    @Test("A panel that can't be decoded doesn't drop the rest")
    func skipsUndecodablePanel() throws {
        let panels = try HAPanels(data: HAData(value: [
            "broken": ["title": "No component name"],
            "lovelace": panel(component: "lovelace", urlPath: "lovelace", title: "Overview"),
        ]))

        #expect(panels.allPanels.map(\.path) == ["lovelace"])
    }

    @Test("Falls back to the url path when the server sends no title")
    func fallsBackToPathWhenTitleIsMissing() throws {
        let panels = try HAPanels(data: HAData(value: [
            "hidden-dashboard": panel(component: "lovelace", urlPath: "hidden-dashboard"),
        ]))

        #expect(panels.panelsByPath["hidden-dashboard"]?.title == "hidden-dashboard")
    }

    @Test("Decodes default_visible, which older servers don't send")
    func decodesDefaultVisible() throws {
        let panels = try HAPanels(data: HAData(value: [
            "energy": panel(component: "energy", urlPath: "energy", title: "Energy", defaultVisible: false),
            "map": panel(component: "map", urlPath: "map", title: "Map"),
        ]))

        #expect(panels.panelsByPath["energy"]?.defaultVisible == false)
        #expect(panels.panelsByPath["map"]?.defaultVisible == nil)
    }

    @Test("Sorts dashboards first, then the built-in panels in the frontend's order")
    func sortsDashboardsFirst() throws {
        let panels = try HAPanels(data: HAData(value: [
            "map": panel(component: "map", urlPath: "map", title: "Map"),
            "energy": panel(component: "energy", urlPath: "energy", title: "Energy"),
            "kitchen": panel(component: "lovelace", urlPath: "kitchen", title: "Kitchen"),
            "home": panel(component: "home", urlPath: "home", title: "home"),
            "light": panel(component: "light", urlPath: "light", title: "light"),
        ]))

        #expect(panels.allPanels.map(\.path) == ["home", "kitchen", "light", "energy", "map"])
    }
}
