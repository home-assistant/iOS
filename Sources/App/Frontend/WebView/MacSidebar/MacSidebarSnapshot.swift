import Foundation
import Shared

/// Everything `MacSidebarItemsBuilder` needs to lay out the sidebar, as the last window resolved it.
/// Cached per server by `MacSidebarSnapshotStore`: the panels, the sidebar preferences and the user's role
/// each arrive in their own asynchronous reply, so a view model starting from nothing rebuilds the list
/// several times over and the rows visibly rearrange under the user.
struct MacSidebarSnapshot: Codable, Equatable {
    var panels: [HAPanel] = []
    var panelOrder: [String]?
    var hiddenPanels: [String]?
    var legacyPanelOrder: [String]?
    var legacyHiddenPanels: [String]?
    var legacyDefaultPanel: String?
    var userDefaultPanel: String?
    var systemDefaultPanel: String?
    var isAdmin = false
    var userName: String?
}
