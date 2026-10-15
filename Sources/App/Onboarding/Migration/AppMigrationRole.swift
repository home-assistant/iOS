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

    /// Whether this build still sets up new servers. The previous app no longer does: existing setups
    /// move to the new app and new ones start there. UI tests lift that to onboard the previous app.
    static var allowsOnboarding: Bool {
        guard current == .previousApp else { return true }
        return Current.appConfiguration != .release
            && ProcessInfo.processInfo.arguments.contains("-AppMigrationAllowOnboarding")
    }
}
