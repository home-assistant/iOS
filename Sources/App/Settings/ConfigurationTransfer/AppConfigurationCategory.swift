import Foundation
import SFSafeSymbols
import Shared

/// One user-configured area of the app carried by a full configuration export.
///
/// The order of the cases is the order the categories are listed on
/// `ImportExportConfigurationView`, which doubles as the disclosure of what an export file holds.
enum AppConfigurationCategory: String, CaseIterable, Codable, Identifiable {
    case appSettings
    case watchConfiguration
    case watchComplications
    case carPlayConfiguration
    case customWidgets
    case appQuickActions
    case macToolbar
    case kiosk
    case notificationCategories
    case notificationSnoozeActions
    case nfcTags
    case remindersSync

    var id: String { rawValue }

    /// Categories backed by a single configuration record rather than a list the user adds items to.
    /// They are shown as included/not configured instead of with an item count.
    var isSingleValue: Bool {
        switch self {
        case .appSettings, .kiosk:
            return true
        case .watchConfiguration, .watchComplications, .carPlayConfiguration, .customWidgets, .appQuickActions,
             .macToolbar, .notificationCategories, .notificationSnoozeActions, .nfcTags, .remindersSync:
            return false
        }
    }

    var title: String {
        switch self {
        case .appSettings:
            return L10n.Settings.Debugging.ConfigurationTransfer.Category.AppSettings.title
        case .watchConfiguration:
            return L10n.Settings.Debugging.ConfigurationTransfer.Category.WatchConfiguration.title
        case .watchComplications:
            return L10n.Settings.Debugging.ConfigurationTransfer.Category.WatchComplications.title
        case .carPlayConfiguration:
            return L10n.Settings.Debugging.ConfigurationTransfer.Category.CarplayConfiguration.title
        case .customWidgets:
            return L10n.Settings.Debugging.ConfigurationTransfer.Category.CustomWidgets.title
        case .appQuickActions:
            return L10n.Settings.Debugging.ConfigurationTransfer.Category.AppQuickActions.title
        case .macToolbar:
            return L10n.Settings.Debugging.ConfigurationTransfer.Category.MacToolbar.title
        case .kiosk:
            return L10n.Settings.Debugging.ConfigurationTransfer.Category.Kiosk.title
        case .notificationCategories:
            return L10n.Settings.Debugging.ConfigurationTransfer.Category.NotificationCategories.title
        case .notificationSnoozeActions:
            return L10n.Settings.Debugging.ConfigurationTransfer.Category.NotificationSnoozeActions.title
        case .nfcTags:
            return L10n.Settings.Debugging.ConfigurationTransfer.Category.NfcTags.title
        case .remindersSync:
            return L10n.Settings.Debugging.ConfigurationTransfer.Category.RemindersSync.title
        }
    }

    /// Spells out the concrete data the category contributes to the file, so the screen can tell the
    /// user what leaves the device before they share it.
    var explanation: String {
        switch self {
        case .appSettings:
            return L10n.Settings.Debugging.ConfigurationTransfer.Category.AppSettings.explanation
        case .watchConfiguration:
            return L10n.Settings.Debugging.ConfigurationTransfer.Category.WatchConfiguration.explanation
        case .watchComplications:
            return L10n.Settings.Debugging.ConfigurationTransfer.Category.WatchComplications.explanation
        case .carPlayConfiguration:
            return L10n.Settings.Debugging.ConfigurationTransfer.Category.CarplayConfiguration.explanation
        case .customWidgets:
            return L10n.Settings.Debugging.ConfigurationTransfer.Category.CustomWidgets.explanation
        case .appQuickActions:
            return L10n.Settings.Debugging.ConfigurationTransfer.Category.AppQuickActions.explanation
        case .macToolbar:
            return L10n.Settings.Debugging.ConfigurationTransfer.Category.MacToolbar.explanation
        case .kiosk:
            return L10n.Settings.Debugging.ConfigurationTransfer.Category.Kiosk.explanation
        case .notificationCategories:
            return L10n.Settings.Debugging.ConfigurationTransfer.Category.NotificationCategories.explanation
        case .notificationSnoozeActions:
            return L10n.Settings.Debugging.ConfigurationTransfer.Category.NotificationSnoozeActions.explanation
        case .nfcTags:
            return L10n.Settings.Debugging.ConfigurationTransfer.Category.NfcTags.explanation
        case .remindersSync:
            return L10n.Settings.Debugging.ConfigurationTransfer.Category.RemindersSync.explanation
        }
    }

    var icon: SFSymbol {
        switch self {
        case .appSettings:
            return .gearshape
        case .watchConfiguration:
            return .applewatchWatchface
        case .watchComplications:
            return .circleFill
        case .carPlayConfiguration:
            return .carFill
        case .customWidgets:
            return .squareTextSquareFill
        case .appQuickActions:
            return .bolt
        case .macToolbar:
            return .menubarRectangle
        case .kiosk:
            return .lockFill
        case .notificationCategories:
            return .bell
        case .notificationSnoozeActions:
            return .clockArrowCirclepath
        case .nfcTags:
            return .tag
        case .remindersSync:
            return .checklistChecked
        }
    }
}
