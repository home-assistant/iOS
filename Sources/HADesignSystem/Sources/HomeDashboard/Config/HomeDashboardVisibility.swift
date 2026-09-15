import Foundation

/// The screen widths something is meant for, the port of the frontend's
/// `SMALL_SCREEN_CONDITION` / `LARGE_SCREEN_CONDITION` media conditions.
public enum HomeDashboardVisibility: Equatable, Sendable {
    case always
    /// Phone-width only. The frontend's threshold is 767px and under.
    case smallScreen
    /// Wide layouts only — the sidebar's summaries, the favourites heading.
    case largeScreen

    /// Whether something with this visibility belongs on a screen of the given width class.
    public func isVisible(isCompact: Bool) -> Bool {
        switch self {
        case .always: true
        case .smallScreen: isCompact
        case .largeScreen: !isCompact
        }
    }
}
