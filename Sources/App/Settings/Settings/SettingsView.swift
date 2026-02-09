import Communicator
import Shared
import SwiftUI

struct SettingsView: View {
    @State private var selectedItem: SettingsItem? = .general
    @State private var showAbout = false
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewControllerProvider: ViewControllerProvider
    @StateObject private var serversObserver = ServersObserver()

    var body: some View {
        Group {
            if Current.isCatalyst {
                macOSView
            } else {
                iOSView
            }
        }
    }

    // MARK: - macOS Split View

    @ViewBuilder
    private var macOSView: some View {
        // Use navigation view since navigation stack has bugs on Mac Catalyst
        // such as no back buttons for navigated views
        NavigationView {
            macOSSidebarContent
            if let selectedItem {
                selectedItem.destinationView
            } else {
                macOSPlaceholder
            }
        }
        .navigationViewStyle(.columns)
    }

    private var macOSSidebarContent: some View {
        List(selection: $selectedItem) {
            // Servers section
            Section(header: Text(L10n.Settings.ConnectionSection.serversHeader)) {
                ServersListView()
            }

            // Other settings items
            Section {
                ForEach(SettingsItem.allVisibleCases, id: \.self) { item in
                    NavigationLink(destination: item.destinationView) {
                        Label {
                            Text(item.title)
                        } icon: {
                            item.icon
                        }
                    }
                }
            }
        }
        .navigationTitle(L10n.Settings.NavigationBar.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if serversObserver.servers.count > 1 {
                    EditButton()
                }
            }
        }
    }

    private var macOSPlaceholder: some View {
        Image(.casita)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(height: 100)
    }

    // MARK: - iOS List View

    @ViewBuilder
    private var iOSView: some View {
        if #available(iOS 16.0, *) {
            iOSViewModern
        } else {
            iOSViewLegacy
        }
    }

    @available(iOS 16.0, *)
    private var iOSViewModern: some View {
        NavigationStack {
            iOSListContent
                .navigationDestination(for: SettingsItem.self) { item in
                    item.destinationView
                }
        }
    }

    private var iOSViewLegacy: some View {
        NavigationView {
            iOSListContent
                .navigationViewStyle(.stack)
        }
    }

    private var iOSListContent: some View {
        List {
            // Servers section
            Section(
                header: Text(L10n.Settings.ConnectionSection.serversHeader),
                footer: Text(L10n.Settings.ConnectionSection.serversFooter)
            ) {
                ServersListView()
            }
            .environment(\.defaultMinListRowHeight, 60)

            // General section
            Section {
                ForEach(SettingsItem.generalItems, id: \.self) { item in
                    NavigationLink(destination: item.destinationView) {
                        settingsItemLabel(item)
                    }
                }
            }

            // Integrations section
            Section {
                ForEach(SettingsItem.integrationItems, id: \.self) { item in
                    NavigationLink(destination: item.destinationView) {
                        settingsItemLabel(item)
                    }
                }
            }

            // Apple Watch section (only on iPhone with paired watch)
            if shouldShowWatchSection {
                Section(header: Text("Apple Watch")) {
                    ForEach(SettingsItem.watchItems, id: \.self) { item in
                        NavigationLink(destination: item.destinationView) {
                            settingsItemLabel(item)
                        }
                    }
                }
            }

            // CarPlay section (only on iPhone)
            if UIDevice.current.userInterfaceIdiom == .phone {
                Section {
                    ForEach(SettingsItem.carPlayItems, id: \.self) { item in
                        NavigationLink(destination: item.destinationView) {
                            settingsItemLabel(item)
                        }
                    }
                }
            }

            // Legacy section
            Section {
                ForEach(SettingsItem.legacyItems, id: \.self) { item in
                    NavigationLink(destination: item.destinationView) {
                        settingsItemLabel(item)
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
                                settingsItemLabel(item)
                                Spacer()
                                item.accessoryIcon
                            }
                        }
                    } else {
                        NavigationLink(destination: item.destinationView) {
                            settingsItemLabel(item)
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
                        settingsItemLabel(.whatsNew)
                        Spacer()
                        SettingsItem.whatsNew.accessoryIcon
                    }
                }
            }

            // About
            Section {
                Button {
                    showAbout = true
                } label: {
                    Label {
                        Text(L10n.Settings.NavigationBar.AboutButton.title)
                    } icon: {
                        Image(systemSymbol: .infoCircle)
                    }
                }
            }
        }
        .navigationTitle(L10n.Settings.NavigationBar.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if !Current.sceneManager.supportsMultipleScenes || !Current.isCatalyst {
                    CloseButton {
                        dismiss()
                    }
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                if serversObserver.servers.count > 1 {
                    EditButton()
                }
            }
        }
        .sheet(isPresented: $showAbout) {
            if #available(iOS 16.0, *) {
                NavigationStack {
                    aboutViewContent
                }
            } else {
                NavigationView {
                    aboutViewContent
                }
                .navigationViewStyle(.stack)
            }
        }
    }

    private func settingsItemLabel(_ item: SettingsItem) -> some View {
        Label {
            Text(item.title)
        } icon: {
            item.icon
        }
    }

    private var aboutViewContent: some View {
        AboutView()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    CloseButton {
                        showAbout = false
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
