import Foundation
import SFSafeSymbols
import Shared

/// The buckets the "Manage Storage" screen groups its rows into.
///
/// The order of the cases is the order the sections appear in when the list is grouped by category,
/// and it also drives the `.category` sort: essential app data first, throw-away bytes last.
enum ManageStorageCategory: String, CaseIterable, Identifiable, Comparable {
    case appData
    case caches
    case webContent
    case logs
    case downloads
    case temporary

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appData:
            return L10n.Settings.Debugging.ManageStorage.Category.AppData.title
        case .caches:
            return L10n.Settings.Debugging.ManageStorage.Category.Caches.title
        case .webContent:
            return L10n.Settings.Debugging.ManageStorage.Category.WebContent.title
        case .logs:
            return L10n.Settings.Debugging.ManageStorage.Category.Logs.title
        case .downloads:
            return L10n.Settings.Debugging.ManageStorage.Category.Downloads.title
        case .temporary:
            return L10n.Settings.Debugging.ManageStorage.Category.Temporary.title
        }
    }

    var explanation: String {
        switch self {
        case .appData:
            return L10n.Settings.Debugging.ManageStorage.Category.AppData.explanation
        case .caches:
            return L10n.Settings.Debugging.ManageStorage.Category.Caches.explanation
        case .webContent:
            return L10n.Settings.Debugging.ManageStorage.Category.WebContent.explanation
        case .logs:
            return L10n.Settings.Debugging.ManageStorage.Category.Logs.explanation
        case .downloads:
            return L10n.Settings.Debugging.ManageStorage.Category.Downloads.explanation
        case .temporary:
            return L10n.Settings.Debugging.ManageStorage.Category.Temporary.explanation
        }
    }

    var icon: SFSymbol {
        switch self {
        case .appData:
            return .externaldriveConnectedToLineBelow
        case .caches:
            return .squareGrid2x2Fill
        case .webContent:
            return .globe
        case .logs:
            return .listDash
        case .downloads:
            return .squareAndArrowDown
        case .temporary:
            return .clockArrowCirclepath
        }
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        let all = Self.allCases
        return (all.firstIndex(of: lhs) ?? 0) < (all.firstIndex(of: rhs) ?? 0)
    }
}
