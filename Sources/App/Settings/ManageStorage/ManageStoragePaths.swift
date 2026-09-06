import Foundation
import Shared

/// Every folder and file the "Manage Storage" screen knows about.
///
/// The screen never reaches for `AppConstants` itself: the paths are handed in, so tests can point
/// the whole inventory at a temporary directory and measure and delete for real.
struct ManageStoragePaths: Equatable {
    var appDatabase: [URL]
    var appPreferences: [URL]
    var legacyRealmStore: [URL]
    var notificationSounds: [URL]
    var widgetCache: [URL]
    var watchItemCache: [URL]
    var frontendAssetCache: [URL]
    var websiteData: [URL]
    var clientEventLog: [URL]
    var notificationHistory: [URL]
    var logFiles: [URL]
    var downloads: [URL]
    var temporaryFiles: [URL]

    /// The real paths on this device.
    static var live: ManageStoragePaths {
        let appGroup = AppConstants.AppGroupContainer
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first

        let databaseFile = AppConstants.appGRDBFile
        return ManageStoragePaths(
            // SQLite keeps its write-ahead log and shared-memory file alongside the database, and
            // the WAL alone is regularly larger than the database itself.
            appDatabase: [
                databaseFile,
                URL(fileURLWithPath: databaseFile.path + "-wal"),
                URL(fileURLWithPath: databaseFile.path + "-shm"),
            ],
            appPreferences: [
                appGroup.appendingPathComponent("Library/Preferences", isDirectory: true),
                library?.appendingPathComponent("Preferences", isDirectory: true),
            ].compactMap { $0 },
            legacyRealmStore: [appGroup.appendingPathComponent("dataStore", isDirectory: true)],
            notificationSounds: [library?.appendingPathComponent("Sounds", isDirectory: true)].compactMap { $0 },
            widgetCache: [AppConstants.widgetsCacheURL],
            watchItemCache: [AppConstants.watchMagicItemsInfo],
            frontendAssetCache: [library?.appendingPathComponent("Caches/WebKit", isDirectory: true)]
                .compactMap { $0 },
            websiteData: [
                library?.appendingPathComponent("WebKit", isDirectory: true),
                library?.appendingPathComponent("Cookies", isDirectory: true),
            ].compactMap { $0 },
            clientEventLog: [AppConstants.clientEventsFile],
            notificationHistory: [AppConstants.notificationHistoryFile],
            logFiles: [AppConstants.LogsDirectory],
            downloads: [AppConstants.DownloadsDirectory],
            temporaryFiles: [URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)]
        )
    }

    /// Every path rooted under `directory`, named after the identifier that owns it. Used by tests
    /// to build a self-contained inventory on disk.
    static func rooted(at directory: URL) -> ManageStoragePaths {
        func path(_ component: String) -> [URL] {
            [directory.appendingPathComponent(component, isDirectory: true)]
        }

        return ManageStoragePaths(
            appDatabase: path(ManageStorageItemID.appDatabase.rawValue),
            appPreferences: path(ManageStorageItemID.appPreferences.rawValue),
            legacyRealmStore: path(ManageStorageItemID.legacyRealmStore.rawValue),
            notificationSounds: path(ManageStorageItemID.notificationSounds.rawValue),
            widgetCache: path(ManageStorageItemID.widgetCache.rawValue),
            watchItemCache: path(ManageStorageItemID.watchItemCache.rawValue),
            frontendAssetCache: path(ManageStorageItemID.frontendAssetCache.rawValue),
            websiteData: path(ManageStorageItemID.websiteData.rawValue),
            clientEventLog: path(ManageStorageItemID.clientEventLog.rawValue),
            notificationHistory: path(ManageStorageItemID.notificationHistory.rawValue),
            logFiles: path(ManageStorageItemID.logFiles.rawValue),
            downloads: path(ManageStorageItemID.downloads.rawValue),
            temporaryFiles: path(ManageStorageItemID.temporaryFiles.rawValue)
        )
    }
}
