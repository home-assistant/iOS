import Foundation
import Shared

/// Which side of the handoff this build is. The previous app (`io.robbie.*`) only ever exports; the
/// new app only ever imports.
enum AppMigrationRole: Equatable {
    case previousApp
    case newApp

    static var current: AppMigrationRole {
        AppConstants.BundleID.hasPrefix("io.robbie.") ? .previousApp : .newApp
    }

    var peer: AppMigrationRole {
        self == .newApp ? .previousApp : .newApp
    }

    /// The scheme registered by each app in addition to `homeassistant://`, so the two apps can
    /// address each other while both are installed. Debug builds get their own suffix, matching
    /// `homeassistant-dev`.
    var urlScheme: String {
        let base = self == .newApp ? "homeassistant-ohf" : "homeassistant-nc"
        return Current.appConfiguration == .release ? base : base + "-dev"
    }

    var baseURL: URL {
        URL(string: "\(urlScheme)://\(AppMigrationLink.host)")!
    }
}
