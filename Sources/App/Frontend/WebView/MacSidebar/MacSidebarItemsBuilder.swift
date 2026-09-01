import Foundation
import Shared

/// Mirrors `computePanels` and `panelSorter` from the frontend's `ha-sidebar.ts`, plus the fixed
/// Settings / Notifications / Profile rows it renders below the panel list.
enum MacSidebarItemsBuilder {
    static let fallbackDefaultPanelPath = "home"
    static let settingsPanelPath = "config"
    static let profilePanelPath = "profile"
    static let notificationsItemId = "notifications"

    private static let fixedPanelPaths: Set<String> = [profilePanelPath, settingsPanelPath, "notfound"]
    private static let lovelaceComponent = "lovelace"
    private static let sortValueByPath: [String: Int] = [
        "energy": 1,
        "map": 2,
        "logbook": 3,
        "history": 4,
    ]
    private static let iconByPath: [String: MaterialDesignIcons] = [
        "calendar": .calendarIcon,
        "energy": .lightningBoltIcon,
        "history": .chartBoxIcon,
        "logbook": .formatListBulletedTypeIcon,
        "map": .tooltipAccountIcon,
        "profile": .accountIcon,
        "media-browser": .playBoxMultipleIcon,
        "todo": .clipboardListIcon,
    ]

    static func resolveDefaultPanelPath(preferred: String?, panels: [HAPanel]) -> String {
        let candidate = preferred ?? fallbackDefaultPanelPath
        if candidate == lovelaceComponent, !panels.contains(where: { $0.path == lovelaceComponent }) {
            return fallbackDefaultPanelPath
        }
        return candidate
    }

    static func mainItems(
        panels: [HAPanel],
        defaultPanelPath: String,
        panelOrder: [String],
        hiddenPanels: [String]
    ) -> [MacSidebarItem] {
        let visible = panels.filter { panel in
            guard !fixedPanelPaths.contains(panel.path) else { return false }
            if panel.path == defaultPanelPath { return true }
            guard panel.rawTitle != nil, panel.showInSidebar, !hiddenPanels.contains(panel.path) else {
                return false
            }
            if panel.defaultVisible == false, !panelOrder.contains(panel.path) {
                return false
            }
            return true
        }

        let reverseSort = Array(panelOrder.reversed())
        let sorted = visible.sorted { lhs, rhs in
            let lhsIndex = reverseSort.firstIndex(of: lhs.path) ?? -1
            let rhsIndex = reverseSort.firstIndex(of: rhs.path) ?? -1
            if lhsIndex != rhsIndex {
                return lhsIndex > rhsIndex
            }
            return isSortedBeforeByDefault(lhs, rhs, defaultPanelPath: defaultPanelPath)
        }

        return sorted.map { panel in
            MacSidebarItem(
                id: panel.path,
                kind: .panel(path: "/" + panel.path),
                title: panel.title,
                icon: icon(for: panel),
                isDashboard: panel.component == lovelaceComponent
            )
        }
    }

    /// The panels the frontend's edit dialog offers to show again: everything hidden by the user plus
    /// the panels that are not visible by default and were never added, never the default panel.
    /// Mirrors `_computeHiddenPanels` in `dialog-edit-sidebar.ts`.
    static func hiddenItems(
        panels: [HAPanel],
        defaultPanelPath: String,
        panelOrder: [String],
        hiddenPanels: [String]
    ) -> [MacSidebarItem] {
        var hiddenPaths = Set(hiddenPanels)
        for panel in panels where panel.defaultVisible == false && !panelOrder.contains(panel.path) {
            hiddenPaths.insert(panel.path)
        }
        hiddenPaths.remove(defaultPanelPath)

        return panels
            .filter { hiddenPaths.contains($0.path) && !fixedPanelPaths.contains($0.path) }
            .sorted(by: isTitleSortedBefore)
            .map { panel in
                MacSidebarItem(
                    id: panel.path,
                    kind: .panel(path: "/" + panel.path),
                    title: panel.title,
                    icon: icon(for: panel),
                    isDashboard: panel.component == lovelaceComponent
                )
            }
    }

    static func fixedItems(
        panels: [HAPanel],
        isAdmin: Bool,
        userName: String?,
        notificationsCount: Int
    ) -> [MacSidebarItem] {
        var items: [MacSidebarItem] = []
        if isAdmin {
            items.append(MacSidebarItem(
                id: settingsPanelPath,
                kind: .panel(path: "/" + settingsPanelPath),
                title: panels.first(where: { $0.path == settingsPanelPath })?.title ?? L10n.Mac.Sidebar.settings,
                icon: .cogIcon
            ))
        }
        items.append(MacSidebarItem(
            id: notificationsItemId,
            kind: .notifications,
            title: L10n.Mac.Sidebar.notifications,
            icon: .bellIcon,
            badge: notificationsCount
        ))
        let profileTitle = userName?.trimmingCharacters(in: .whitespacesAndNewlines)
        items.append(MacSidebarItem(
            id: profilePanelPath,
            kind: .profile,
            title: profileTitle.flatMap { $0.isEmpty ? nil : $0 }
                ?? panels.first(where: { $0.path == profilePanelPath })?.title
                ?? Current.localized.frontend("panel::profile")
                ?? profilePanelPath,
            icon: .accountIcon
        ))
        return items
    }

    /// The sidebar row for a frontend path such as `/lovelace/0` or `/config/dashboard`.
    static func itemId(forPath path: String?) -> String? {
        guard let path else { return nil }
        let first = path.split(separator: "/", omittingEmptySubsequences: true).first
        return first.map(String.init)
    }

    private static func isSortedBeforeByDefault(_ lhs: HAPanel, _ rhs: HAPanel, defaultPanelPath: String) -> Bool {
        if lhs.path == defaultPanelPath { return true }
        if rhs.path == defaultPanelPath { return false }

        let lhsLovelace = lhs.component == lovelaceComponent
        let rhsLovelace = rhs.component == lovelaceComponent
        if lhsLovelace, rhsLovelace { return isTitleSortedBefore(lhs, rhs) }
        if lhsLovelace { return true }
        if rhsLovelace { return false }

        let lhsSort = sortValueByPath[lhs.path]
        let rhsSort = sortValueByPath[rhs.path]
        if let lhsSort, let rhsSort { return lhsSort < rhsSort }
        if lhsSort != nil { return true }
        if rhsSort != nil { return false }

        return isTitleSortedBefore(lhs, rhs)
    }

    private static func isTitleSortedBefore(_ lhs: HAPanel, _ rhs: HAPanel) -> Bool {
        lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }

    private static func icon(for panel: HAPanel) -> MaterialDesignIcons {
        if let icon = iconByPath[panel.path] {
            return icon
        }
        let fallback: MaterialDesignIcons = panel
            .component == lovelaceComponent ? .viewDashboardIcon : .viewDashboardOutlineIcon
        guard let iconName = panel.icon, !iconName.isEmpty else { return fallback }
        return MaterialDesignIcons(serversideValueNamed: iconName, fallback: fallback)
    }
}
