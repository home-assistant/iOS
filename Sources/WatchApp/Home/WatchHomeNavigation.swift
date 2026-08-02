import Foundation
import Shared

/// Every screen the watch home hierarchy can push, registered once at the stack root
/// (`WatchHomeView`) via `navigationDestination(for:)`. Rows navigate by appending one of these
/// to the stack's path through the `watchNavigate` environment action, so pushes work (and
/// animate) identically from the home list, the grid, and inside folders.
enum WatchHomeNavigation: Hashable {
    /// A folder's contents.
    case folder(String)
    /// The controls screen (power/brightness/color/temperature) of a capable light.
    case lightControls(MagicItem)
    /// The controls screen (position/open/stop/close) of a capable cover.
    case coverControls(MagicItem)
    /// The controls screen (power/speed) of a capable fan.
    case fanControls(MagicItem)
}
