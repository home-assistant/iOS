import Foundation
import Shared

/// Whether the previous app should tell the user about the new app. Shown once per device like a
/// What's New release, then reachable from Settings until the transfer has happened.
enum AppMigrationAnnouncement {
    static let releaseID = "app-migration-announcement-2026.9"

    /// The new app's App Store identifier, for the in-app store overlay.
    static let newAppStoreID = "6805469843"

    /// Where the new app lives on the App Store, for platforms without the overlay.
    static let newAppStoreURL = URL(string: "https://apps.apple.com/app/id\(newAppStoreID)")!

    static var isRelevant: Bool {
        AppMigrationRole.current == .previousApp && !AppMigrationHandoffStore.isActive
    }

    static var shouldPresentAtLaunch: Bool {
        isRelevant && !Current.settingsStore.hasSeenWhatsNew(releaseID: releaseID)
    }

    static func markSeen() {
        Current.settingsStore.markWhatsNewSeen(releaseID: releaseID)
    }
}
