import Foundation

/// A tab of the App Labs native iOS tab bar: a sidebar page pinned to the bar, More, or Search. Search is
/// never the selection; tapping it opens the frontend's quick search instead.
enum NativeTabBarTab: Hashable {
    case panel(id: String)
    case more
    case search
}
