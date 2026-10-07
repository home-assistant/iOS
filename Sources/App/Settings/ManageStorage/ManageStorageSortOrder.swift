import Foundation
import Shared

/// How the "Manage Storage" list is ordered. It orders the rows inside every category section and,
/// for the size-based orders, the sections themselves — so "largest first" really does put the
/// biggest thing on the screen first, not just the biggest thing in an arbitrary section.
enum ManageStorageSortOrder: String, CaseIterable, Identifiable {
    case largestFirst
    case smallestFirst
    case name

    var id: String { rawValue }

    var title: String {
        switch self {
        case .largestFirst:
            return L10n.Settings.Debugging.ManageStorage.Sort.largestFirst
        case .smallestFirst:
            return L10n.Settings.Debugging.ManageStorage.Sort.smallestFirst
        case .name:
            return L10n.Settings.Debugging.ManageStorage.Sort.name
        }
    }

    /// Ties break on title so rows keep a stable position between refreshes, which matters here
    /// because most rows measure zero on a fresh install.
    func sort(_ items: [ManageStorageItem]) -> [ManageStorageItem] {
        items.sorted { lhs, rhs in
            switch self {
            case .largestFirst where lhs.byteCount != rhs.byteCount:
                return lhs.byteCount > rhs.byteCount
            case .smallestFirst where lhs.byteCount != rhs.byteCount:
                return lhs.byteCount < rhs.byteCount
            default:
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        }
    }

    func sort(_ sections: [ManageStorageSection]) -> [ManageStorageSection] {
        sections.sorted { lhs, rhs in
            switch self {
            case .largestFirst where lhs.byteCount != rhs.byteCount:
                return lhs.byteCount > rhs.byteCount
            case .smallestFirst where lhs.byteCount != rhs.byteCount:
                return lhs.byteCount < rhs.byteCount
            default:
                return lhs.category < rhs.category
            }
        }
    }
}
