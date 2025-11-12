import Communicator
import Shared
import SwiftUI

struct SettingsView: View {
    @State private var selectedItem: SettingsItem? = .servers
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var showAbout = false
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewControllerProvider: ViewControllerProvider

    var body: some View {
        Group {
            #if targetEnvironment(macCatalyst)
            if UIScreen.main.traitCollection.userInterfaceIdiom == .mac {
                macOSView
            } else {
                iOSView
            }
            #else
            iOSView
            #endif
        }
        .onAppear {
            Task {
                await Current.appDatabaseUpdater.update()
            }
        }
    }

    // MARK: - macOS Split View

    private var macOSView: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            // Sidebar
            List(selection: $selectedItem) {
                ForEach(SettingsItem.allVisibleCases, id: \.self) { item in
                    NavigationLink(value: item) {
                        Label {
                            Text(item.title)
                        } icon: {
                            item.icon
                        }
                    }
                }
            }
            .navigationTitle(L10n.Settings.NavigationBar.title)
        } detail: {
            // Detail view
            NavigationStack {
                if let selectedItem {
                    selectedItem.destinationView
                } else {
                    Text("Select a setting")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    // MARK: - iOS List View

    private var iOSView: some View {
        NavigationStack {
            List {
                // Servers section
                Section(
                    header: Text(L10n.Settings.ConnectionSection.serversHeader),
                    footer: Text(L10n.Settings.ConnectionSection.serversFooter)
                ) {
                    ServersListView()
                }

                // General section
                Section {
                    ForEach(SettingsItem.generalItems, id: \.self) { item in
                        NavigationLink(value: item) {
                            Label {
                                Text(item.title)
                            } icon: {
                                item.icon
                            }
                        }
                    }
                }

                // Integrations section
                Section {
                    ForEach(SettingsItem.integrationItems, id: \.self) { item in
                        NavigationLink(value: item) {
                            Label {
                                Text(item.title)
                            } icon: {
                                item.icon
                            }
                        }
                    }
                }

                // Apple Watch section (only on iPhone with paired watch)
                if shouldShowWatchSection {
                    Section(header: Text("Apple Watch")) {
                        ForEach(SettingsItem.watchItems, id: \.self) { item in
                            NavigationLink(value: item) {
                                Label {
                                    Text(item.title)
                                } icon: {
                                    item.icon
                                }
                            }
                        }
                    }
                }

                // CarPlay section (only on iPhone)
                if UIDevice.current.userInterfaceIdiom == .phone {
                    Section {
                        ForEach(SettingsItem.carPlayItems, id: \.self) { item in
                            NavigationLink(value: item) {
                                Label {
                                    Text(item.title)
                                } icon: {
                                    item.icon
                                }
                            }
                        }
                    }
                }

                // Legacy section
                Section {
                    ForEach(SettingsItem.legacyItems, id: \.self) { item in
                        NavigationLink(value: item) {
                            Label {
                                Text(item.title)
                            } icon: {
                                item.icon
                            }
                        }
                    }
                }

                // Help section
                Section {
                    ForEach(SettingsItem.helpItems, id: \.self) { item in
                        if item == .help {
                            Button {
                                if let url = URL(string: "https://companion.home-assistant.io") {
                                    openURLInBrowser(url, viewControllerProvider.viewController)
                                }
                            } label: {
                                HStack {
                                    Label {
                                        Text(item.title)
                                    } icon: {
                                        item.icon
                                    }
                                    Spacer()
                                    item.accessoryIcon
                                }
                            }
                        } else {
                            NavigationLink(value: item) {
                                Label {
                                    Text(item.title)
                                } icon: {
                                    item.icon
                                }
                            }
                        }
                    }
                }

                // What's New
                Section {
                    Button {
                        if let url = URL(string: "https://www.home-assistant.io/latest-ios-release-notes/") {
                            openURLInBrowser(url, viewControllerProvider.viewController)
                        }
                    } label: {
                        HStack {
                            Label {
                                Text(SettingsItem.whatsNew.title)
                            } icon: {
                                SettingsItem.whatsNew.icon
                            }
                            Spacer()
                            SettingsItem.whatsNew.accessoryIcon
                        }
                    }
                }
            }
            .navigationTitle(L10n.Settings.NavigationBar.title)
            .toolbar {
                if !Current.isCatalyst {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(L10n.Settings.NavigationBar.AboutButton.title) {
                            showAbout = true
                        }
                    }
                }
                if !Current.sceneManager.supportsMultipleScenes || !Current.isCatalyst {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
            .navigationDestination(for: SettingsItem.self) { item in
                item.destinationView
            }
            .sheet(isPresented: $showAbout) {
                NavigationStack {
                    AboutView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") {
                                    showAbout = false
                                }
                            }
                        }
                }
            }
        }
    }

    private var shouldShowWatchSection: Bool {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return false }
        if Current.isDebug {
            return true
        } else if case .paired = Communicator.shared.currentWatchState {
            return true
        }
        return false
    }
}

// MARK: - Settings Items

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
                .navigationTitle(title)
        case .gestures:
            GesturesSetupView()
                .navigationTitle(title)
        case .location:
            SettingsLocationView()
        case .notifications:
            SettingsNotificationsView()
        case .sensors:
            SensorListView()
                .navigationTitle(title)
        case .nfc:
            SettingsNFCView()
        case .widgets:
            WidgetBuilderView()
                .navigationTitle(title)
        case .watch:
            WatchConfigurationView()
                .navigationTitle(title)
        case .carPlay:
            CarPlayConfigurationView()
                .navigationTitle(title)
        case .complications:
            SettingsComplicationsView()
        case .actions:
            SettingsActionsView()
        case .help:
            EmptyView()
        case .privacy:
            PrivacyView()
                .navigationTitle(title)
        case .debugging:
            DebugView()
                .navigationTitle(title)
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

// MARK: - Servers List View

private class ServersObserver: ObservableObject, ServerObserver {
    @Published var servers: [Server] = []

    init() {
        self.servers = Current.servers.all
        Current.servers.add(observer: self)
    }

    deinit {
        Current.servers.remove(observer: self)
    }

    func serversDidChange(_ serverManager: ServerManager) {
        DispatchQueue.main.async { [weak self] in
            self?.servers = serverManager.all
        }
    }
}

struct ServersListView: View {
    @StateObject private var observer = ServersObserver()
    @State private var showAddServer = false

    var body: some View {
        ForEach(observer.servers, id: \.identifier) { server in
            NavigationLink(destination: ConnectionSettingsView(server: server)) {
                HomeAssistantAccountRowView(server: server)
            }
        }

        Button {
            showAddServer = true
        } label: {
            Text(L10n.Settings.ConnectionSection.addServer)
        }
        .sheet(isPresented: $showAddServer) {
            OnboardingNavigationView(onboardingStyle: .secondary)
        }
    }
}

// MARK: - Account Row View

struct HomeAssistantAccountRowView: View {
    let server: Server

    var body: some View {
        HStack {
            // Account icon
            Circle()
                .fill(Color.blue)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(server.info.name.prefix(1).uppercased())
                        .foregroundColor(.white)
                )

            VStack(alignment: .leading) {
                Text(server.info.name)
                    .font(.headline)
                if let url = server.info.connection.activeURL() {
                    Text(url.host ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
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
        embed(SettingsViewController(contentSections: .servers))
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
