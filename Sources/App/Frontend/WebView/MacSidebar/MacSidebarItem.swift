import Foundation
import Shared

struct MacSidebarItem: Identifiable, Hashable {
    enum Kind: Hashable {
        case panel(path: String)
        case notifications
        case profile
    }

    let id: String
    let kind: Kind
    let title: String
    let icon: MaterialDesignIcons
    var badge: Int = 0
    /// Lovelace dashboards are the only panels the frontend lets a user pick as their default.
    var isDashboard = false

    var navigationPath: String? {
        switch kind {
        case let .panel(path): return path
        case .profile: return "/profile"
        case .notifications: return nil
        }
    }
}
