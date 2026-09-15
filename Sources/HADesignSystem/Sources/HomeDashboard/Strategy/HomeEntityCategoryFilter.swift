import Foundation

/// What a filter means by an entity's category. The registry leaves the category unset for a primary
/// entity; the frontend's filters spell that absence `"none"` and match on it, which is how the home
/// dashboard asks for "controls, not configuration".
public enum HomeEntityCategoryFilter: String, Equatable, Hashable, Sendable {
    case none
    case config
    case diagnostic

    /// The filter value an entity's registry category corresponds to.
    public static func of(_ category: HomeEntityCategory?) -> HomeEntityCategoryFilter {
        switch category {
        case .none: .none
        case .config: .config
        case .diagnostic: .diagnostic
        }
    }
}
