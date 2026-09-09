import Foundation

/// Where the app's own entries sit in the tab bar's list, per server. `nil` means the entry is hidden. Search
/// starts in the fourth slot, the search role of the bar; Assist starts at the end of the list.
struct NativeTabBarExtras: Codable, Equatable {
    static let standard = NativeTabBarExtras(searchPosition: 3, assistPosition: Int.max)

    var searchPosition: Int?
    var assistPosition: Int?

    func position(of kind: NativeTabBarItem.Kind) -> Int? {
        switch kind {
        case .search: return searchPosition
        case .assist: return assistPosition
        case .panel: return nil
        }
    }

    mutating func setPosition(_ position: Int?, of kind: NativeTabBarItem.Kind) {
        switch kind {
        case .search: searchPosition = position
        case .assist: assistPosition = position
        case .panel: break
        }
    }
}
