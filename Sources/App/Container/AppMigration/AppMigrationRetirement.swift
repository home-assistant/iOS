import Foundation
import Shared

/// Stands the app being replaced down once the new app has confirmed the import.
///
/// The two apps share the Home Assistant side of the world: the migrated servers keep the same
/// webhook, so the `mobile_app` device in Home Assistant is the *same* device for both. Leaving the
/// old app running would mean two apps posting sensor and location updates for one device and
/// fighting over which push token it points at.
///
/// Deliberately not done here: signing the servers out. That would delete the `mobile_app`
/// registration the new app has just taken over, breaking every automation that targets it. The old
/// app keeps its credentials and simply stops using them.
enum AppMigrationRetirement {
    @MainActor
    static func retire(importedServerCount: Int) {
        guard !AppMigrationStatus.isRetired else { return }
        Current.Log.info("Retiring this app after migrating \(importedServerCount) server(s)")

        AppMigrationStatus.handedOffAt = Current.date()

        var locationSources = Current.settingsStore.locationSources
        locationSources.zone = false
        locationSources.backgroundFetch = false
        locationSources.significantLocationChange = false
        locationSources.pushNotifications = false
        Current.settingsStore.locationSources = locationSources
    }
}
