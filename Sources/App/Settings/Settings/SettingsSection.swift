import Shared

/// Groups settings entries by the objective a user has when opening the app settings,
/// e.g. customizing the app, staying informed or getting help.
enum SettingsSection: String, CaseIterable, Hashable {
    case customizeExperience
    case stayInformed
    case shareFromDevice
    case quickAccess
    case otherDevices
    case privacySecurity
    case helpSupport
    case appLabs

    /// Nil for groups whose single entry already names itself, so the list shows no header.
    var header: String? {
        switch self {
        case .customizeExperience: return L10n.Settings.Sections.CustomizeExperience.header
        case .stayInformed: return L10n.Settings.Sections.StayInformed.header
        case .shareFromDevice: return L10n.Settings.Sections.ShareFromDevice.header
        case .quickAccess: return L10n.Settings.Sections.QuickAccess.header
        case .otherDevices: return L10n.Settings.Sections.OtherDevices.header
        case .privacySecurity: return L10n.Settings.Sections.PrivacySecurity.header
        case .helpSupport: return L10n.Settings.Sections.HelpSupport.header
        case .appLabs: return nil
        }
    }

    /// All entries belonging to this group, before platform visibility filtering.
    var allItems: [SettingsItem] {
        switch self {
        case .customizeExperience: return [.general, .gestures, .greetings, .kiosk, .macToolbar]
        case .stayInformed: return [.notifications, .liveActivities]
        case .shareFromDevice: return [.location, .sensors, .remindersSync, .voiceToolsServer]
        case .quickAccess: return [.widgets, .appIconShortcuts, .siri, .nfc]
        case .otherDevices: return [.watch, .complications, .carPlay]
        case .privacySecurity: return [.permissions, .privacy]
        case .helpSupport: return [.help, .debugging]
        case .appLabs: return [.appLabs]
        }
    }

    /// Groups rendered above the settings list's trailing rows (What's New, Beta Tester Updates,
    /// About), so `appLabs` can be rendered below them and land at the very bottom of the list.
    static var groupsAboveTrailingRows: [SettingsSection] {
        allCases.filter { $0 != .appLabs }
    }

    /// Entries visible on the current platform and device.
    var items: [SettingsItem] {
        allItems.filter(\.isVisible)
    }

    /// Entries matching the given search query, visible on the current platform and device.
    func items(matching searchQuery: String) -> [SettingsItem] {
        items.filter { $0.matches(searchQuery: searchQuery) }
    }
}
