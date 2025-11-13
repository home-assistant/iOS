import Communicator
import Shared
import SwiftUI

struct SettingsView: View {
    @State private var selectedItem: SettingsItem? = .servers
    @State private var showAbout = false
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewControllerProvider: ViewControllerProvider

    @State private var appDatabaseUpdaterTask: Task<Void, Never>?

    var body: some View {
        Group {
            if Current.isCatalyst {
                macOSView
            } else {
                iOSView
            }
        }
        .onAppear {
            appDatabaseUpdaterTask?.cancel()
            appDatabaseUpdaterTask = Task {
                await Current.appDatabaseUpdater.update()
            }
        }
    }

    // MARK: - macOS Split View

    private var macOSView: some View {
        NavigationView {
            List(selection: $selectedItem) {
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
            .navigationTitle(L10n.Settings.NavigationBar.title)
            if let selectedItem {
                selectedItem.destinationView
            } else {
                Image(.casita)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 100)
            }
        }
        .navigationViewStyle(.columns)
    }

    // MARK: - iOS List View

    private var iOSView: some View {
        NavigationView {
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
                        NavigationLink(destination: item.destinationView) {
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
                        NavigationLink(destination: item.destinationView) {
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

                // CarPlay section (only on iPhone)
                if UIDevice.current.userInterfaceIdiom == .phone {
                    Section {
                        ForEach(SettingsItem.carPlayItems, id: \.self) { item in
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

                // Legacy section
                Section {
                    ForEach(SettingsItem.legacyItems, id: \.self) { item in
                        NavigationLink(destination: item.destinationView) {
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !Current.isCatalyst {
                        Button(L10n.Settings.NavigationBar.AboutButton.title) {
                            showAbout = true
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !Current.sceneManager.supportsMultipleScenes || !Current.isCatalyst {
                        if #available(iOS 26.0, *) {
                            Button(role: .confirm) {
                                dismiss()
                            }
                            .tint(.haPrimary)
                            .buttonStyle(.glassProminent)
                        } else {
                            Button {
                                dismiss()
                            } label: {
                                Image(systemSymbol: .checkmark)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showAbout) {
                NavigationView {
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
                .navigationViewStyle(.stack)
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
