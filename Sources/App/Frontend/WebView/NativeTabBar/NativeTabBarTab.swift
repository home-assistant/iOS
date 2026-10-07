import Foundation

/// A tab of the App Labs native iOS tab bar.
enum NativeTabBarTab: Hashable {
    case panel(id: String)
    case more
    case search
    case assist
}
