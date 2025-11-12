import Shared
import SwiftUI

enum SettingsItem: String, Hashable, CaseIterable {
    case servers
    case general
    case gestures
    case location
    case notifications
    case sensors
    case nfc
    case widgets
    case watch
    case carPlay
    case complications
    case actions
    case help
    case privacy
    case debugging
    case whatsNew

    var title: String {
        switch self {
        case .servers: return L10n.Settings.ConnectionSection.servers
        case .general: return L10n.SettingsDetails.General.title
        case .gestures: return L10n.Gestures.Screen.title
        case .location: return L10n.Settings.DetailsSection.LocationSettingsRow.title
        case .notifications: return L10n.Settings.DetailsSection.NotificationSettingsRow.title
        case .sensors: return L10n.SettingsSensors.title
        case .nfc: return L10n.Nfc.List.title
        case .widgets: return L10n.Settings.Widgets.title
        case .watch: return L10n.Settings.DetailsSection.WatchRowConfiguration.title
        case .carPlay: return "CarPlay"
        case .complications: return L10n.Settings.DetailsSection.WatchRowComplications.title
        case .actions: return L10n.SettingsDetails.LegacyActions.title
        case .help: return L10n.helpLabel
        case .privacy: return L10n.SettingsDetails.Privacy.title
        case .debugging: return L10n.Settings.Debugging.title
        case .whatsNew: return L10n.Settings.WhatsNew.title
        }
    }

    var icon: some View {
        Group {
            switch self {
            case .servers:
                MaterialDesignIconsImage(icon: .serverIcon, size: 24)
            case .general:
                MaterialDesignIconsImage(icon: .paletteOutlineIcon, size: 24)
            case .gestures:
                MaterialDesignIconsImage(icon: .gestureIcon, size: 24)
            case .location:
                MaterialDesignIconsImage(icon: .crosshairsGpsIcon, size: 24)
            case .notifications:
                MaterialDesignIconsImage(icon: .bellOutlineIcon, size: 24)
            case .sensors:
                MaterialDesignIconsImage(icon: .formatListBulletedIcon, size: 24)
            case .nfc:
                MaterialDesignIconsImage(icon: .nfcVariantIcon, size: 24)
            case .widgets:
                MaterialDesignIconsImage(icon: .widgetsIcon, size: 24)
            case .watch:
                MaterialDesignIconsImage(icon: .watchVariantIcon, size: 24)
            case .carPlay:
                MaterialDesignIconsImage(icon: .carBackIcon, size: 24)
            case .complications:
                MaterialDesignIconsImage(icon: .chartDonutIcon, size: 24)
            case .actions:
                MaterialDesignIconsImage(icon: .gamepadVariantOutlineIcon, size: 24)
            case .help:
                MaterialDesignIconsImage(icon: .helpCircleOutlineIcon, size: 24)
            case .privacy:
                MaterialDesignIconsImage(icon: .lockOutlineIcon, size: 24)
            case .debugging:
                MaterialDesignIconsImage(icon: .bugIcon, size: 24)
            case .whatsNew:
                MaterialDesignIconsImage(icon: .starIcon, size: 24)
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
        case .location:
            SettingsLocationView()
        case .notifications:
            SettingsNotificationsView()
        case .sensors:
            SensorListView()
        case .nfc:
            SettingsNFCView()
        case .widgets:
            WidgetBuilderView()
        case .watch:
            WatchConfigurationView()
                .environment(\.colorScheme, .dark)
        case .carPlay:
            CarPlayConfigurationView()
        case .complications:
            SettingsComplicationsView()
        case .actions:
            SettingsActionsView()
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
            // Filter based on platform
            #if targetEnvironment(macCatalyst)
            if item == .gestures || item == .watch || item == .carPlay ||
                item == .complications || item == .nfc || item == .help ||
                item == .whatsNew {
                return false
            }
            #endif
            return true
        }
    }

    static func visibleCases(for contentSections: SettingsView.ContentSection) -> [SettingsItem] {
        allCases.filter { item in
            // Filter based on platform
            #if targetEnvironment(macCatalyst)
            if item == .gestures || item == .watch || item == .carPlay ||
                item == .complications || item == .nfc || item == .help ||
                item == .whatsNew {
                return false
            }
            #endif

            // Filter based on contentSections
            switch item {
            case .servers:
                return contentSections.contains(.servers)
            case .general, .gestures, .location, .notifications:
                return contentSections.contains(.general)
            case .sensors, .nfc, .widgets:
                return contentSections.contains(.integrations)
            case .watch, .complications:
                return contentSections.contains(.watch)
            case .carPlay:
                return contentSections.contains(.carPlay)
            case .actions:
                return contentSections.contains(.legacy)
            case .help, .privacy, .debugging:
                return contentSections.contains(.help)
            case .whatsNew:
                return true // Always show whatsNew (matching old behavior)
            }
        }
    }

    static var generalItems: [SettingsItem] {
        [.general, .gestures, .location, .notifications]
    }

    static var integrationItems: [SettingsItem] {
        [.sensors, .nfc, .widgets]
    }

    static var watchItems: [SettingsItem] {
        [.watch, .complications]
    }

    static var carPlayItems: [SettingsItem] {
        [.carPlay]
    }

    static var legacyItems: [SettingsItem] {
        [.actions]
    }

    static var helpItems: [SettingsItem] {
        [.help, .privacy, .debugging]
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

struct SettingsLocationView: View {
    var body: some View {
        let viewController = SettingsDetailViewController()
        viewController.detailGroup = .location
        return embed(viewController)
            .navigationTitle(L10n.Settings.DetailsSection.LocationSettingsRow.title)
    }
}

struct SettingsNotificationsView: View {
    var body: some View {
        embed(NotificationSettingsViewController())
            .navigationTitle(L10n.Settings.DetailsSection.NotificationSettingsRow.title)
    }
}

struct SettingsNFCView: View {
    var body: some View {
        embed(NFCListViewController())
            .navigationTitle(L10n.Nfc.List.title)
    }
}

struct SettingsComplicationsView: View {
    var body: some View {
        embed(ComplicationListViewController())
            .navigationTitle(L10n.Settings.DetailsSection.WatchRowComplications.title)
    }
}

struct SettingsActionsView: View {
    var body: some View {
        let viewController = SettingsDetailViewController()
        viewController.detailGroup = .actions
        return embed(viewController)
            .navigationTitle(L10n.SettingsDetails.LegacyActions.title)
    }
}
