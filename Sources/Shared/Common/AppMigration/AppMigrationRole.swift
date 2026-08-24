import Foundation

/// Which side of the developer-account migration the running build plays.
///
/// One codebase produces both apps, so the role is derived from the bundle identifier rather than a
/// build setting: the app published under the original account offers to hand its data over, the app
/// published under the new one accepts it.
public enum AppMigrationRole {
    /// The app being replaced. It exports and hands off.
    case source
    /// The app taking over. It receives and imports.
    case destination

    public static var current: AppMigrationRole {
        AppConstants.BundleID.hasPrefix(AppMigrationConstants.sourceBundleID) ? .source : .destination
    }

    /// The scheme this role listens on, used to build the URL the *other* role opens.
    public var urlScheme: String {
        switch self {
        case .source: return AppMigrationConstants.sourceURLScheme
        case .destination: return AppMigrationConstants.destinationURLScheme
        }
    }
}
