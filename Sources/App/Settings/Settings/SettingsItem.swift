import Shared
import SwiftUI

enum SettingsItem: String, Hashable, CaseIterable {
    case servers
    case general
    case gestures
    case greetings
    case kiosk
    case location
    case remindersSync
    case notifications
    case liveActivities
    case sensors
    case nfc
    case macToolbar
    case widgets
    case appIconShortcuts
    case watch
    case carPlay
    case complications
    case help
    case permissions
    case privacy
    case debugging
    case appLabs
    case whatsNew

    var title: String {
        switch self {
        case .servers: return L10n.Settings.ConnectionSection.servers
        case .general: return L10n.SettingsDetails.General.title
        case .macToolbar: return L10n.Settings.MacToolbar.title
        case .gestures: return L10n.Gestures.Screen.title
        case .greetings: return L10n.Settings.Greetings.title
        case .kiosk: return L10n.Kiosk.title
        case .location: return L10n.Settings.DetailsSection.LocationSettingsRow.title
        case .remindersSync: return L10n.Settings.RemindersSync.title
        case .notifications: return L10n.Settings.DetailsSection.NotificationSettingsRow.title
        case .liveActivities: return L10n.LiveActivity.title
        case .sensors: return L10n.SettingsSensors.title
        case .nfc: return L10n.Tags.title
        case .widgets: return L10n.Settings.Widgets.title
        case .appIconShortcuts: return L10n.Settings.AppIconShortcuts.title
        case .watch: return L10n.Settings.DetailsSection.WatchRowConfiguration.title
        case .carPlay: return "CarPlay"
        case .complications: return L10n.Settings.DetailsSection.WatchRowComplications.title
        case .help: return L10n.helpLabel
        case .permissions: return L10n.SettingsSensors.Permissions.header
        case .privacy: return L10n.SettingsDetails.Privacy.title
        case .debugging: return L10n.Settings.Debugging.title
        case .appLabs: return L10n.Settings.AppLabs.title
        case .whatsNew: return L10n.Settings.WhatsNew.title
        }
    }

    private static let iconSize: CGFloat = 24

    var materialIcon: MaterialDesignIcons {
        switch self {
        case .servers: return .serverIcon
        case .general: return .paletteOutlineIcon
        case .macToolbar: return .dockWindowIcon
        case .gestures: return .gestureIcon
        case .greetings: return .airplaneIcon
        case .kiosk: return .tabletDashboardIcon
        case .location: return .crosshairsGpsIcon
        case .remindersSync: return .formatListChecksIcon
        case .notifications: return .bellOutlineIcon
        case .liveActivities: return .playBoxOutlineIcon
        case .sensors: return .formatListBulletedIcon
        case .nfc: return .nfcVariantIcon
        case .widgets: return .widgetsIcon
        case .appIconShortcuts: return .applicationIcon
        case .watch: return .watchVariantIcon
        case .carPlay: return .carBackIcon
        case .complications: return .chartDonutIcon
        case .help: return .helpCircleOutlineIcon
        case .permissions: return .shieldKeyOutlineIcon
        case .privacy: return .lockOutlineIcon
        case .debugging: return .bugIcon
        case .appLabs: return .flaskOutlineIcon
        case .whatsNew: return .starIcon
        }
    }

    var icon: some View {
        icon(size: Self.iconSize)
    }

    func icon(size: CGFloat) -> some View {
        MaterialDesignIconsImage(icon: materialIcon, size: size)
    }

    var accessoryIcon: some View {
        Group {
            if self == .help || self == .whatsNew {
                MaterialDesignIconsImage(icon: .openInNewIcon, size: 18)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    var destinationView: some View {
        switch self {
        case .servers:
            SettingsServersView()
        case .general:
            GeneralSettingsView()
        case .macToolbar:
            MacToolbarSettingsView()
        case .gestures:
            GesturesSetupView()
        case .greetings:
            GreetingsSettingsView()
        case .kiosk:
            KioskSettingsView()
        case .location:
            LocationSettingsView()
        case .remindersSync:
            RemindersSyncSettingsView()
        case .notifications:
            SettingsNotificationsView()
        case .liveActivities:
            #if os(iOS) && !targetEnvironment(macCatalyst)
            if #available(iOS 17.2, *) {
                LiveActivitySettingsView()
            }
            #else
            EmptyView()
            #endif
        case .sensors:
            SensorListView()
        case .nfc:
            TagsView()
        case .widgets:
            CustomWidgetsListView()
        case .appIconShortcuts:
            AppIconShortcutsConfigurationView()
        case .watch:
            WatchConfigurationView()
                .environment(\.colorScheme, .dark)
        case .carPlay:
            CarPlayConfigurationView()
        case .complications:
            SettingsComplicationsView()
        case .help:
            EmptyView()
        case .permissions:
            SensorPermissionsView()
        case .privacy:
            PrivacyView()
        case .debugging:
            DebugView()
        case .appLabs:
            AppLabsView()
        case .whatsNew:
            EmptyView()
        }
    }

    var isVisible: Bool {
        // Filter based on platform
        #if targetEnvironment(macCatalyst)
        // Kiosk mode is unsupported on macOS.
        let hiddenItems: [SettingsItem] = [
            .servers,
            .gestures,
            .kiosk,
            .watch,
            .carPlay,
            .appIconShortcuts,
            .complications,
            .nfc,
            .help,
            .whatsNew,
            // Sandboxed Catalyst builds lack the calendars entitlement EventKit needs.
            .remindersSync,
        ]

        if hiddenItems.contains(self) {
            return false
        }
        #endif

        switch self {
        case .liveActivities:
            return Self.canShowLiveActivities
        case .macToolbar:
            // Managing toolbar entities only makes sense on macOS, where the toolbar exists.
            return Current.isCatalyst
        case .watch, .complications:
            return Self.isWatchAvailable
        case .carPlay:
            return UIDevice.current.userInterfaceIdiom == .phone
        case .appLabs:
            // App Labs is limited to TestFlight builds while its features mature.
            return AppLabsFeature.isLabsAvailable
        default:
            return true
        }
    }

    /// Localized synonyms used by the settings search index, in addition to the item title.
    var searchKeywords: [String] {
        guard let keywords = localizedSearchKeywords else { return [] }
        return keywords
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private var localizedSearchKeywords: String? {
        switch self {
        case .servers: return L10n.Settings.SearchKeywords.servers
        case .general: return L10n.Settings.SearchKeywords.general
        case .macToolbar: return L10n.Settings.SearchKeywords.macToolbar
        case .gestures: return L10n.Settings.SearchKeywords.gestures
        case .greetings: return L10n.Settings.SearchKeywords.greetings
        case .kiosk: return L10n.Settings.SearchKeywords.kiosk
        case .location: return L10n.Settings.SearchKeywords.location
        case .remindersSync: return L10n.Settings.SearchKeywords.remindersSync
        case .notifications: return L10n.Settings.SearchKeywords.notifications
        case .liveActivities: return L10n.Settings.SearchKeywords.liveActivities
        case .sensors: return L10n.Settings.SearchKeywords.sensors
        case .nfc: return L10n.Settings.SearchKeywords.nfc
        case .widgets: return L10n.Settings.SearchKeywords.widgets
        case .appIconShortcuts: return L10n.Settings.SearchKeywords.appIconShortcuts
        case .watch: return L10n.Settings.SearchKeywords.watch
        case .carPlay: return L10n.Settings.SearchKeywords.carPlay
        case .complications: return L10n.Settings.SearchKeywords.complications
        case .help: return L10n.Settings.SearchKeywords.help
        case .permissions: return L10n.Settings.SearchKeywords.permissions
        case .privacy: return L10n.Settings.SearchKeywords.privacy
        case .debugging: return L10n.Settings.SearchKeywords.debugging
        case .appLabs: return L10n.Settings.SearchKeywords.appLabs
        case .whatsNew: return nil
        }
    }

    /// Searchable rows provided by the destination screen, so screen content is
    /// indexed by the root settings search.
    var contentSearchEntries: [SettingsSearchEntry] {
        switch self {
        case .servers: return SettingsServersView.settingsSearchEntries
        case .general: return GeneralSettingsView.settingsSearchEntries
        case .macToolbar: return MacToolbarSettingsView.settingsSearchEntries
        case .gestures: return GesturesSetupView.settingsSearchEntries
        case .greetings: return GreetingsSettingsView.settingsSearchEntries
        case .kiosk: return KioskSettingsView.settingsSearchEntries
        case .location: return LocationSettingsView.settingsSearchEntries
        case .remindersSync: return RemindersSyncSettingsView.settingsSearchEntries
        case .notifications: return NotificationSettingsView.settingsSearchEntries
        case .liveActivities:
            #if os(iOS) && !targetEnvironment(macCatalyst)
            if #available(iOS 17.2, *) {
                return LiveActivitySettingsView.settingsSearchEntries
            }
            return []
            #else
            return []
            #endif
        case .sensors: return SensorListView.settingsSearchEntries
        case .nfc: return TagsView.settingsSearchEntries
        case .widgets: return CustomWidgetsListView.settingsSearchEntries
        case .appIconShortcuts: return AppIconShortcutsConfigurationView.settingsSearchEntries
        case .watch: return WatchConfigurationView.settingsSearchEntries
        case .carPlay: return CarPlayConfigurationView.settingsSearchEntries
        case .complications: return ComplicationsRootView.settingsSearchEntries
        case .permissions: return SensorPermissionsView.settingsSearchEntries
        case .privacy: return PrivacyView.settingsSearchEntries
        case .debugging: return DebugView.settingsSearchEntries
        case .appLabs: return AppLabsView.settingsSearchEntries
        case .help, .whatsNew: return []
        }
    }

    /// The destination screen rows matching the given query, surfaced as the
    /// subtitle of this item in search results.
    func contentMatches(searchQuery: String) -> [SettingsSearchEntry] {
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return [] }
        return contentSearchEntries.filter { $0.matches(searchQuery: query) }
    }

    /// A short listing of matched screen rows, shown as the row subtitle in
    /// search results, or nil when the query matches no screen content.
    func contentMatchesSubtitle(searchQuery: String) -> String? {
        let matched = contentMatches(searchQuery: searchQuery)
        guard !matched.isEmpty else { return nil }
        return matched.prefix(3).map(\.title).joined(separator: ", ")
    }

    func matches(searchQuery: String) -> Bool {
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        if title.localizedStandardContains(query) {
            return true
        }
        if searchKeywords.contains(where: { $0.localizedStandardContains(query) }) {
            return true
        }
        return !contentMatches(searchQuery: query).isEmpty
    }

    private static var isWatchAvailable: Bool {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return false }
        if Current.isDebug {
            return true
        } else if case .paired = Communicator.shared.lastKnownWatchState {
            // The cached state, not `currentWatchState`: `isVisible` runs on the main thread for
            // every settings list evaluation, and the live getters synchronously wait on WCSession's
            // internal operation queue, which can stall while the session is busy.
            return true
        }
        return false
    }

    private static var canShowLiveActivities: Bool {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        if #available(iOS 17.2, *) {
            return true
        } else {
            return false
        }
        #else
        return false
        #endif
    }
}

// MARK: - Wrapper Views for UIKit Controllers

struct SettingsNotificationsView: View {
    var body: some View {
        NotificationSettingsView()
    }
}

struct SettingsComplicationsView: View {
    var body: some View {
        ComplicationsRootView()
            .navigationTitle(L10n.Settings.DetailsSection.WatchRowComplications.title)
    }
}
