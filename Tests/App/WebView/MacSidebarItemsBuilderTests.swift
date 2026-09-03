@testable import HomeAssistant
import Shared
import Testing

struct MacSidebarItemsBuilderTests {
    private func panel(
        _ path: String,
        component: String = "lovelace",
        title: String? = nil,
        showInSidebar: Bool = true,
        defaultVisible: Bool? = nil
    ) -> HAPanel {
        HAPanel(
            icon: nil,
            title: title ?? path,
            path: path,
            component: component,
            showInSidebar: showInSidebar,
            defaultVisible: defaultVisible,
            rawTitle: title
        )
    }

    @Test("Default panel first, dashboards alphabetically, then built-ins in frontend order, then the rest")
    func defaultOrder() {
        let panels = [
            panel("history", component: "history", title: "History"),
            panel("zeta", title: "Zeta"),
            panel("map", component: "map", title: "Map"),
            panel("alpha", title: "Alpha"),
            panel("energy", component: "energy", title: "Energy"),
            panel("home", component: "home", title: "Overview"),
            panel("todo", component: "todo", title: "To-do lists"),
            panel("calendar", component: "calendar", title: "Calendar"),
        ]

        let items = MacSidebarItemsBuilder.mainItems(
            panels: panels,
            defaultPanelPath: "home",
            panelOrder: [],
            hiddenPanels: []
        )

        #expect(items.map(\.id) == ["home", "alpha", "zeta", "energy", "map", "history", "calendar", "todo"])
        #expect(items.first?.navigationPath == "/home")
    }

    @Test("Add-on ingress panels are listed like any other panel, with a puzzle fallback icon")
    func addOnIngressPanels() {
        let panels = [
            panel("home", component: "home", title: "Overview"),
            panel("45df7312_zigbee2mqtt", component: "app", title: "Zigbee2MQTT"),
            panel("core_matter_server", component: "app", title: "Matter Server"),
            panel("energy", component: "energy", title: "Energy"),
        ]

        let items = MacSidebarItemsBuilder.mainItems(
            panels: panels,
            defaultPanelPath: "home",
            panelOrder: [],
            hiddenPanels: []
        )

        #expect(items.map(\.id) == ["home", "energy", "core_matter_server", "45df7312_zigbee2mqtt"])
        #expect(items.last?.navigationPath == "/45df7312_zigbee2mqtt")
        #expect(items.last?.icon == .material(.puzzleIcon))
        #expect(items.last?.isDashboard == false)
    }

    @Test("User panel order wins over the default order")
    func userOrder() {
        let panels = [
            panel("alpha", title: "Alpha"),
            panel("map", component: "map", title: "Map"),
            panel("energy", component: "energy", title: "Energy"),
            panel("home", component: "home", title: "Overview"),
        ]

        let items = MacSidebarItemsBuilder.mainItems(
            panels: panels,
            defaultPanelPath: "home",
            panelOrder: ["map", "energy"],
            hiddenPanels: []
        )

        #expect(items.map(\.id) == ["map", "energy", "home", "alpha"])
    }

    @Test("Hidden, untitled, fixed and not-visible-by-default panels are left out, except the default panel")
    func visibility() {
        let panels = [
            panel("home", component: "home", title: "Overview", showInSidebar: false),
            panel("hidden", title: "Hidden"),
            panel("untitled"),
            panel("off", title: "Off", showInSidebar: false),
            panel("light", component: "light", title: "Lights", defaultVisible: false),
            panel("security", component: "security", title: "Security", defaultVisible: false),
            panel("config", component: "config", title: "Settings"),
            panel("profile", component: "profile", title: "Profile"),
            panel("shown", title: "Shown"),
        ]

        let items = MacSidebarItemsBuilder.mainItems(
            panels: panels,
            defaultPanelPath: "home",
            panelOrder: ["security"],
            hiddenPanels: ["hidden"]
        )

        #expect(items.map(\.id) == ["security", "home", "shown"])
    }

    @Test("Legacy lovelace default falls back to home when no lovelace panel exists")
    func defaultPanelResolution() {
        let panels = [panel("home", component: "home", title: "Overview")]
        #expect(MacSidebarItemsBuilder.resolveDefaultPanelPath(preferred: "lovelace", panels: panels) == "home")
        #expect(MacSidebarItemsBuilder.resolveDefaultPanelPath(preferred: nil, panels: panels) == "home")
        #expect(MacSidebarItemsBuilder.resolveDefaultPanelPath(preferred: "alpha", panels: panels) == "alpha")
        #expect(MacSidebarItemsBuilder.resolveDefaultPanelPath(
            preferred: "lovelace",
            panels: panels + [panel("lovelace", title: "Overview")]
        ) == "lovelace")
    }

    @Test("Fixed rows: Settings only for admins, then notifications with badge, then the profile")
    func fixedItems() {
        let panels = [panel("config", component: "config", title: "Settings")]

        let admin = MacSidebarItemsBuilder.fixedItems(
            panels: panels,
            isAdmin: true,
            userName: "Bruno",
            notificationsCount: 3
        )
        #expect(admin.map(\.id) == ["config", "notifications", "profile"])
        #expect(admin[1].badge == 3)
        #expect(admin[2].title == "Bruno")
        #expect(admin[2].navigationPath == "/profile")
        #expect(admin[1].navigationPath == nil)

        let user = MacSidebarItemsBuilder.fixedItems(
            panels: panels,
            isAdmin: false,
            userName: " ",
            notificationsCount: 0
        )
        #expect(user.map(\.id) == ["notifications", "profile"])
        #expect(user[1].title == "Profile")
    }

    @Test("Selection follows the first path component")
    func selection() {
        #expect(MacSidebarItemsBuilder.itemId(forPath: "/lovelace/0") == "lovelace")
        #expect(MacSidebarItemsBuilder.itemId(forPath: "/config/dashboard") == "config")
        #expect(MacSidebarItemsBuilder.itemId(forPath: "/") == nil)
        #expect(MacSidebarItemsBuilder.itemId(forPath: nil) == nil)
    }

    @Test("Hidden items: user-hidden and not-visible-by-default panels, never the default or fixed panels")
    func hiddenItems() {
        let panels = [
            panel("home", title: "Home"),
            panel("alpha", title: "Alpha"),
            panel("light", title: "Light", showInSidebar: false, defaultVisible: false),
            panel("climate", title: "Climate", showInSidebar: false, defaultVisible: false),
            panel("config", component: "config", title: "Settings"),
        ]
        let items = MacSidebarItemsBuilder.hiddenItems(
            panels: panels,
            defaultPanelPath: "home",
            panelOrder: ["home", "climate"],
            hiddenPanels: ["alpha", "home"]
        )
        #expect(items.map(\.id) == ["alpha", "light"])
    }
}
