import Foundation

/// A tab of the App Labs native iOS tab bar: a sidebar page pinned to the bar, More, Search or Assist. Search
/// and Assist are never the selection; tapping them runs their action instead.
enum NativeTabBarTab: Hashable {
    case panel(id: String)
    case more
    case search
    case assist
}
