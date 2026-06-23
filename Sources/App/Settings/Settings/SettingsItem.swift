import Shared
import SwiftUI

enum SettingsItem: String, Hashable, CaseIterable {
    case servers
    case general
    case gestures
    case kiosk
    case location
    case notifications
    case liveActivities
    case sensors
    case nfc
    case widgets
    case appIconShortcuts
    case watch
    case carPlay
    case complications
    case help
    case privacy
    case debugging
    case whatsNew

    var title: String {
        switch self {
        case .servers: return L10n.Settings.ConnectionSection.servers
        case .general: return L10n.SettingsDetails.General.title
        case .gestures: return L10n.Gestures.Screen.title
        case .kiosk: return L10n.Kiosk.title
        case .location: return L10n.Settings.DetailsSection.LocationSettingsRow.title
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
        case .privacy: return L10n.SettingsDetails.Privacy.title
        case .debugging: return L10n.Settings.Debugging.title
        case .whatsNew: return L10n.Settings.WhatsNew.title
        }
    }

    private static let iconSize: CGFloat = 24

    var icon: some View {
        Group {
            switch self {
            case .servers:
                MaterialDesignIconsImage(icon: .serverIcon, size: Self.iconSize)
            case .general:
                MaterialDesignIconsImage(icon: .paletteOutlineIcon, size: Self.iconSize)
            case .gestures:
                MaterialDesignIconsImage(icon: .gestureIcon, size: Self.iconSize)
            case .kiosk:
                MaterialDesignIconsImage(icon: .tabletDashboardIcon, size: Self.iconSize)
            case .location:
                MaterialDesignIconsImage(icon: .crosshairsGpsIcon, size: Self.iconSize)
            case .notifications:
                MaterialDesignIconsImage(icon: .bellOutlineIcon, size: Self.iconSize)
            case .liveActivities:
                MaterialDesignIconsImage(icon: .playBoxOutlineIcon, size: Self.iconSize)
            case .sensors:
                MaterialDesignIconsImage(icon: .formatListBulletedIcon, size: Self.iconSize)
            case .nfc:
                MaterialDesignIconsImage(icon: .nfcVariantIcon, size: Self.iconSize)
            case .widgets:
                MaterialDesignIconsImage(icon: .widgetsIcon, size: Self.iconSize)
            case .appIconShortcuts:
                MaterialDesignIconsImage(icon: .applicationIcon, size: Self.iconSize)
            case .watch:
                MaterialDesignIconsImage(icon: .watchVariantIcon, size: Self.iconSize)
            case .carPlay:
                MaterialDesignIconsImage(icon: .carBackIcon, size: Self.iconSize)
            case .complications:
                MaterialDesignIconsImage(icon: .chartDonutIcon, size: Self.iconSize)
            case .help:
                MaterialDesignIconsImage(icon: .helpCircleOutlineIcon, size: Self.iconSize)
            case .privacy:
                MaterialDesignIconsImage(icon: .lockOutlineIcon, size: Self.iconSize)
            case .debugging:
                MaterialDesignIconsImage(icon: .bugIcon, size: Self.iconSize)
            case .whatsNew:
                MaterialDesignIconsImage(icon: .starIcon, size: Self.iconSize)
            }
        }
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
        case .gestures:
            GesturesSetupView()
        case .kiosk:
            KioskSettingsView()
        case .location:
            LocationSettingsView()
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
            CarPlayConfigurationView(needsNavigationController: false)
        case .complications:
            SettingsComplicationsView()
        case .help:
            EmptyView()
        case .privacy:
            PrivacyView()
        case .debugging:
            DebugView()
        case .whatsNew:
            EmptyView()
        }
    }

    static var allVisibleCases: [SettingsItem] {
        allCases.filter { item in
            if item == .liveActivities {
                return canShowLiveActivities
            }

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
            ]

            if hiddenItems.contains(item) {
                return false
            }
            #endif

            return true
        }
    }

    static var generalItems: [SettingsItem] {
        var items: [SettingsItem] = [.general, .gestures, .location, .notifications, .kiosk]
        if canShowLiveActivities {
            items.append(.liveActivities)
        }
        return items
    }

    static var integrationItems: [SettingsItem] {
        [.sensors, .nfc, .widgets, .appIconShortcuts]
    }

    static var watchItems: [SettingsItem] {
        [.watch, .complications]
    }

    static var carPlayItems: [SettingsItem] {
        [.carPlay]
    }

    static var helpItems: [SettingsItem] {
        [.help, .privacy, .debugging]
    }

    private static var canShowLiveActivities: Bool {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        if #available(iOS 17.2, *) {
            return Current.isTestFlight
        } else {
            return false
        }
        #else
        return false
        #endif
    }
}

// MARK: - Material Design Icons Image

struct MaterialDesignIconsImage: View {
    let icon: MaterialDesignIcons
    let size: CGFloat

    var body: some View {
        Image(uiImage: icon.image(ofSize: CGSize(width: size, height: size), color: .label))
            .renderingMode(.template)
    }
}

// MARK: - Wrapper Views for UIKit Controllers

struct SettingsServersView: View {
    var body: some View {
        List {
            Section(
                header: Text(L10n.Settings.ConnectionSection.serversHeader),
                footer: Text(L10n.Settings.ConnectionSection.serversFooter)
            ) {
                ServersListView()
            }
        }
        .navigationTitle(L10n.Settings.ConnectionSection.servers)
    }
}

struct SettingsNotificationsView: View {
    var body: some View {
        NotificationSettingsView()
    }
}

struct SettingsComplicationsView: View {
    var body: some View {
        ComplicationListView()
            .navigationTitle(L10n.Settings.DetailsSection.WatchRowComplications.title)
    }
}
