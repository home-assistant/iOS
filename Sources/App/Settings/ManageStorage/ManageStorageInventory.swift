import Foundation
import Shared
import WebKit

/// Builds the list of everything the "Manage Storage" screen shows, and decides what the user is
/// allowed to delete.
///
/// This is the single place that answers "is this junk?". Everything else on the screen — sorting,
/// filtering, measuring, deleting — treats the answer as given.
enum ManageStorageInventory {
    /// Website data types cleared by the "Website data" row. The frontend authenticates with tokens
    /// held in the keychain rather than cookies, so dropping these only costs a fresh page load.
    static let websiteDataTypes: Set<String> = [
        WKWebsiteDataTypeCookies,
        WKWebsiteDataTypeLocalStorage,
        WKWebsiteDataTypeSessionStorage,
        WKWebsiteDataTypeIndexedDBDatabases,
    ]

    static func items(
        paths: ManageStoragePaths,
        isCatalyst: Bool,
        hasCompletedLegacyStoreMigration: Bool
    ) -> [ManageStorageItem] {
        [
            ManageStorageItem(
                id: .appDatabase,
                category: .appData,
                // Servers, tokens' companion records, watch/CarPlay/widget configuration and every
                // other thing the user set up by hand lives here. Nothing re-syncs it.
                protection: .protected(.essentialAppData),
                source: .files(paths.appDatabase)
            ),
            ManageStorageItem(
                id: .appPreferences,
                category: .appData,
                protection: .protected(.essentialAppData),
                source: .files(paths.appPreferences)
            ),
            ManageStorageItem(
                id: .legacyRealmStore,
                category: .appData,
                // Until the importer has run, this store is the only copy of the zones, notification
                // categories and complications it still holds.
                protection: hasCompletedLegacyStoreMigration ? .deletable : .protected(.pendingMigration),
                source: .files(paths.legacyRealmStore)
            ),
            ManageStorageItem(
                id: .notificationSounds,
                category: .appData,
                // The user imported these files; the app has no way to fetch them again.
                protection: .protected(.userProvidedContent),
                source: .files(paths.notificationSounds)
            ),
            ManageStorageItem(
                id: .cachedEntities,
                category: .caches,
                protection: .deletable,
                source: .databaseTables([
                    GRDBDatabaseTable.HAAppEntity.rawValue,
                    GRDBDatabaseTable.displayEntityRegistry.rawValue,
                    GRDBDatabaseTable.deviceRegistry.rawValue,
                ]),
                countsTowardTotal: false
            ),
            ManageStorageItem(
                id: .cachedCalendarEvents,
                category: .caches,
                protection: .deletable,
                source: .databaseTables([GRDBDatabaseTable.HACalendarEvent.rawValue]),
                countsTowardTotal: false
            ),
            ManageStorageItem(
                id: .locationHistory,
                category: .logs,
                protection: .deletable,
                source: .databaseTables([
                    GRDBDatabaseTable.locationHistory.rawValue,
                    GRDBDatabaseTable.locationError.rawValue,
                ]),
                countsTowardTotal: false
            ),
            ManageStorageItem(
                id: .widgetCache,
                category: .caches,
                protection: .deletable,
                source: .files(paths.widgetCache)
            ),
            ManageStorageItem(
                id: .watchItemCache,
                category: .caches,
                protection: .deletable,
                source: .files(paths.watchItemCache)
            ),
            ManageStorageItem(
                id: .networkResponseCache,
                category: .caches,
                protection: .deletable,
                source: .networkResponseCache
            ),
            ManageStorageItem(
                id: .frontendAssetCache,
                category: .webContent,
                protection: .deletable,
                source: .webKit(
                    urls: paths.frontendAssetCache,
                    dataTypes: WebsiteDataStoreHandlerImpl.frontendAssetDataTypes
                )
            ),
            ManageStorageItem(
                id: .websiteData,
                category: .webContent,
                protection: .deletable,
                source: .webKit(urls: paths.websiteData, dataTypes: websiteDataTypes)
            ),
            ManageStorageItem(
                id: .clientEventLog,
                category: .logs,
                protection: .deletable,
                source: .files(paths.clientEventLog)
            ),
            ManageStorageItem(
                id: .notificationHistory,
                category: .logs,
                protection: .deletable,
                source: .files(paths.notificationHistory)
            ),
            ManageStorageItem(
                id: .logFiles,
                category: .logs,
                protection: .deletable,
                source: .files(paths.logFiles)
            ),
            ManageStorageItem(
                id: .downloads,
                category: .downloads,
                // On Mac the app writes straight into the user's own Downloads folder, which holds
                // files no part of this app put there.
                protection: isCatalyst ? .protected(.outsideAppControl) : .deletable,
                source: .files(paths.downloads)
            ),
            ManageStorageItem(
                id: .temporaryFiles,
                category: .temporary,
                protection: .deletable,
                source: .files(paths.temporaryFiles)
            ),
        ]
    }
}
