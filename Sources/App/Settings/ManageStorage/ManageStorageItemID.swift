import Foundation
import SFSafeSymbols
import Shared

/// One measurable pile of bytes the app is responsible for.
///
/// The identifier is stable and never localized: it is what the view model, the measurer and the
/// cleaner agree on, and what tests assert against.
enum ManageStorageItemID: String, CaseIterable, Identifiable {
    // App data
    case appDatabase
    case appPreferences
    case legacyRealmStore
    case notificationSounds
    // Stored inside the app database
    case cachedEntities
    case cachedCalendarEvents
    case locationHistory
    // Caches
    case widgetCache
    case watchItemCache
    case diskCache
    case notificationIconCache
    case networkResponseCache
    // Web content
    case frontendAssetCache
    case websiteData
    // Logs
    case clientEventLog
    case notificationHistory
    case logFiles
    // Downloads and scratch space
    case downloads
    case temporaryFiles

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appDatabase:
            return L10n.Settings.Debugging.ManageStorage.Item.AppDatabase.title
        case .appPreferences:
            return L10n.Settings.Debugging.ManageStorage.Item.AppPreferences.title
        case .legacyRealmStore:
            return L10n.Settings.Debugging.ManageStorage.Item.LegacyRealmStore.title
        case .notificationSounds:
            return L10n.Settings.Debugging.ManageStorage.Item.NotificationSounds.title
        case .cachedEntities:
            return L10n.Settings.Debugging.ManageStorage.Item.CachedEntities.title
        case .cachedCalendarEvents:
            return L10n.Settings.Debugging.ManageStorage.Item.CachedCalendarEvents.title
        case .locationHistory:
            return L10n.Settings.Debugging.ManageStorage.Item.LocationHistory.title
        case .widgetCache:
            return L10n.Settings.Debugging.ManageStorage.Item.WidgetCache.title
        case .watchItemCache:
            return L10n.Settings.Debugging.ManageStorage.Item.WatchItemCache.title
        case .diskCache:
            return L10n.Settings.Debugging.ManageStorage.Item.DiskCache.title
        case .notificationIconCache:
            return L10n.Settings.Debugging.ManageStorage.Item.NotificationIconCache.title
        case .networkResponseCache:
            return L10n.Settings.Debugging.ManageStorage.Item.NetworkResponseCache.title
        case .frontendAssetCache:
            return L10n.Settings.Debugging.ManageStorage.Item.FrontendAssetCache.title
        case .websiteData:
            return L10n.Settings.Debugging.ManageStorage.Item.WebsiteData.title
        case .clientEventLog:
            return L10n.Settings.Debugging.ManageStorage.Item.ClientEventLog.title
        case .notificationHistory:
            return L10n.Settings.Debugging.ManageStorage.Item.NotificationHistory.title
        case .logFiles:
            return L10n.Settings.Debugging.ManageStorage.Item.LogFiles.title
        case .downloads:
            return L10n.Settings.Debugging.ManageStorage.Item.Downloads.title
        case .temporaryFiles:
            return L10n.Settings.Debugging.ManageStorage.Item.TemporaryFiles.title
        }
    }

    /// Spells out what the row actually holds, and — for deletable rows — how the app recovers from
    /// deleting it, so the user can tell junk from something they would miss.
    var explanation: String {
        switch self {
        case .appDatabase:
            return L10n.Settings.Debugging.ManageStorage.Item.AppDatabase.explanation
        case .appPreferences:
            return L10n.Settings.Debugging.ManageStorage.Item.AppPreferences.explanation
        case .legacyRealmStore:
            return L10n.Settings.Debugging.ManageStorage.Item.LegacyRealmStore.explanation
        case .notificationSounds:
            return L10n.Settings.Debugging.ManageStorage.Item.NotificationSounds.explanation
        case .cachedEntities:
            return L10n.Settings.Debugging.ManageStorage.Item.CachedEntities.explanation
        case .cachedCalendarEvents:
            return L10n.Settings.Debugging.ManageStorage.Item.CachedCalendarEvents.explanation
        case .locationHistory:
            return L10n.Settings.Debugging.ManageStorage.Item.LocationHistory.explanation
        case .widgetCache:
            return L10n.Settings.Debugging.ManageStorage.Item.WidgetCache.explanation
        case .watchItemCache:
            return L10n.Settings.Debugging.ManageStorage.Item.WatchItemCache.explanation
        case .diskCache:
            return L10n.Settings.Debugging.ManageStorage.Item.DiskCache.explanation
        case .notificationIconCache:
            return L10n.Settings.Debugging.ManageStorage.Item.NotificationIconCache.explanation
        case .networkResponseCache:
            return L10n.Settings.Debugging.ManageStorage.Item.NetworkResponseCache.explanation
        case .frontendAssetCache:
            return L10n.Settings.Debugging.ManageStorage.Item.FrontendAssetCache.explanation
        case .websiteData:
            return L10n.Settings.Debugging.ManageStorage.Item.WebsiteData.explanation
        case .clientEventLog:
            return L10n.Settings.Debugging.ManageStorage.Item.ClientEventLog.explanation
        case .notificationHistory:
            return L10n.Settings.Debugging.ManageStorage.Item.NotificationHistory.explanation
        case .logFiles:
            return L10n.Settings.Debugging.ManageStorage.Item.LogFiles.explanation
        case .downloads:
            return L10n.Settings.Debugging.ManageStorage.Item.Downloads.explanation
        case .temporaryFiles:
            return L10n.Settings.Debugging.ManageStorage.Item.TemporaryFiles.explanation
        }
    }

    var icon: SFSymbol {
        switch self {
        case .appDatabase:
            return .externaldriveConnectedToLineBelow
        case .appPreferences:
            return .gearshapeFill
        case .legacyRealmStore:
            return .arrow2Squarepath
        case .notificationSounds:
            return .speakerWave2Fill
        case .cachedEntities:
            return .tablecells
        case .cachedCalendarEvents:
            return .calendar
        case .locationHistory:
            return .mappinAndEllipse
        case .widgetCache:
            return .squareGrid2x2Fill
        case .watchItemCache:
            return .applewatchWatchface
        case .diskCache:
            return .photoFill
        case .notificationIconCache:
            return .envelopeBadgeFill
        case .networkResponseCache:
            return .network
        case .frontendAssetCache:
            return .globe
        case .websiteData:
            return .docTextFill
        case .clientEventLog:
            return .listDash
        case .notificationHistory:
            return .bell
        case .logFiles:
            return .docZipper
        case .downloads:
            return .squareAndArrowDown
        case .temporaryFiles:
            return .clockArrowCirclepath
        }
    }
}
