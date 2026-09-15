import Foundation

/// The two shapes a view takes: a grid of sections, or one card filling the screen.
public enum HomeDashboardViewContent: Equatable, Sendable {
    case sections([HomeDashboardSectionConfig])
    case panel([HomeDashboardCardConfig])

    public var sections: [HomeDashboardSectionConfig] {
        switch self {
        case let .sections(sections): sections
        case .panel: []
        }
    }
}
