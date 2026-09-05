import Foundation
import Shared

/// Packages everything the app being replaced can hand to the app taking over.
///
/// Both halves are produced by machinery that already exists: the servers come from
/// `ServerManager.restorableState()` — the same encoding the watch is synced with — and the
/// configuration from an `AppConfigurationTransfer` export. Nothing new is serialized here, which
/// means a category added to either of those travels in the migration automatically.
enum AppMigrationExporter {
    /// Collects the servers half. Cheap and always available, even when the configuration fails.
    static func serversState() -> Data {
        Current.servers.restorableState()
    }

    /// Collects the configuration half. Capturing the app settings has to happen on the main actor;
    /// encoding does not, so callers can hand this off the main thread.
    static func configurationData(appSettings: AppSettingsSnapshot) throws -> Data {
        try AppConfigurationTransfer.exportData(appSettings: appSettings)
    }

    static func makePayload(servers: Data, configuration: Data?, serverCount: Int) -> AppMigrationPayload {
        AppMigrationPayload(
            exportedAt: Current.date(),
            sourceBundleID: AppConstants.BundleID,
            sourceAppVersion: AppConstants.version,
            servers: servers,
            configuration: configuration,
            serverCount: serverCount,
            configurationEntryCount: configuration.flatMap(entryCount(inConfiguration:)) ?? 0
        )
    }

    /// How many configured things the payload carries, for the "N items" line on both screens.
    /// Reported as zero rather than failing: the count is a nicety, the migration is not.
    private static func entryCount(inConfiguration data: Data) -> Int {
        do {
            return try AppConfigurationTransfer.inspectImportData(data).values.reduce(0, +)
        } catch {
            Current.Log.error("Failed to count app migration configuration entries: \(error.localizedDescription)")
            return 0
        }
    }
}
