import Shared

/// Groups settings entries by the objective a user has when opening the app settings,
/// e.g. customizing the app, staying informed or getting help.
enum SettingsSection: String, CaseIterable, Hashable {
    case customizeExperience
    case stayInformed
    case shareFromDevice
    case quickAccess
    case otherDevices
    case helpSupport

    var header: String {
        switch self {
        case .customizeExperience: return L10n.Settings.Sections.CustomizeExperience.header
        case .stayInformed: return L10n.Settings.Sections.StayInformed.header
        case .shareFromDevice: return L10n.Settings.Sections.ShareFromDevice.header
        case .quickAccess: return L10n.Settings.Sections.QuickAccess.header
        case .otherDevices: return L10n.Settings.Sections.OtherDevices.header
        case .helpSupport: return L10n.Settings.Sections.HelpSupport.header
        }
    }

    /// All entries belonging to this group, before platform visibility filtering.
    var allItems: [SettingsItem] {
        switch self {
        case .customizeExperience: return [.general, .gestures, .kiosk, .macToolbar]
        case .stayInformed: return [.notifications, .liveActivities]
        case .shareFromDevice: return [.location, .sensors, .remindersSync]
        case .quickAccess: return [.widgets, .appIconShortcuts, .nfc]
        case .otherDevices: return [.watch, .complications, .carPlay]
        case .helpSupport: return [.help, .privacy, .debugging]
        }
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
