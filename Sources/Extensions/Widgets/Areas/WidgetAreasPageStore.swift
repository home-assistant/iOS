import Foundation
import Shared
import WidgetKit

/// Which page of areas a widget is showing.
///
/// WidgetKit gives a widget no identity of its own, so the page is remembered per server and per
/// family: a small and a large Areas widget page independently, and two identical widgets on the
/// same server turn together. The store lives in the app group because the arrows run as App
/// Intents, in a process of their own, and the timeline is built in yet another.
enum WidgetAreasPageStore {
    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppConstants.AppGroupID)
    }

    static func page(serverId: String, family: WidgetFamily) -> Int {
        defaults?.integer(forKey: key(serverId: serverId, family: family)) ?? 0
    }

    static func setPage(_ page: Int, serverId: String, family: WidgetFamily) {
        defaults?.set(page, forKey: key(serverId: serverId, family: family))
    }

    /// The page to draw: the stored one while it exists, the last one once areas have gone away
    /// under it, and the first one when there is nothing to show at all.
    static func clamp(_ page: Int, pageCount: Int) -> Int {
        guard pageCount > 0 else { return 0 }
        return min(max(page, 0), pageCount - 1)
    }

    private static func key(serverId: String, family: WidgetFamily) -> String {
        "widget-areas-page-\(serverId)-\(family.rawValue)"
    }
}
