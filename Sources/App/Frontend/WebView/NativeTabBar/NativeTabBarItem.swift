import Foundation
import Shared

/// An entry of the tab bar's ordered list: a sidebar page, or one of the app's own entries (Search, Assist).
struct NativeTabBarItem: Identifiable, Hashable {
    enum Kind: Hashable {
        case panel(MacSidebarItem)
        case search
        case assist
    }

    static let searchID = "tab-bar-search"
    static let assistID = "tab-bar-assist"

    let kind: Kind

    var id: String {
        switch kind {
        case let .panel(item): return item.id
        case .search: return Self.searchID
        case .assist: return Self.assistID
        }
    }

    var title: String {
        switch kind {
        case let .panel(item): return item.title
        case .search: return L10n.TabBar.Item.search
        case .assist: return L10n.TabBar.Item.assist
        }
    }

    var icon: FrontendIcon {
        switch kind {
        case let .panel(item): return item.icon
        case .search: return .material(.magnifyIcon)
        case .assist: return .material(.messageProcessingOutlineIcon)
        }
    }

    var sidebarItem: MacSidebarItem? {
        if case let .panel(item) = kind {
            return item
        }
        return nil
    }

    var tab: NativeTabBarTab {
        switch kind {
        case let .panel(item): return .panel(id: item.id)
        case .search: return .search
        case .assist: return .assist
        }
    }
}
