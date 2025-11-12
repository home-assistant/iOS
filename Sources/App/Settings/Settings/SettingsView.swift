import Communicator
import Shared
import SwiftUI

struct SettingsView: View {
    struct ContentSection: OptionSet {
        let rawValue: Int

        static let servers: ContentSection = .init(rawValue: 1 << 0)
        static let general: ContentSection = .init(rawValue: 1 << 1)
        static let integrations: ContentSection = .init(rawValue: 1 << 2)
        static let watch: ContentSection = .init(rawValue: 1 << 3)
        static let carPlay: ContentSection = .init(rawValue: 1 << 4)
        static let legacy: ContentSection = .init(rawValue: 1 << 5)
        static let help: ContentSection = .init(rawValue: 1 << 6)
        static let all: ContentSection = [.servers, .general, .integrations, .watch, .carPlay, .legacy, .help]
    }

    let contentSections: ContentSection

    @State private var selectedItem: SettingsItem? = .servers
    @State private var showAbout = false
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var viewControllerProvider: ViewControllerProvider

    @State private var appDatabaseUpdaterTask: Task<Void, Never>?

    init(contentSections: ContentSection = .all) {
        self.contentSections = contentSections
    }

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
        let visibleItems = SettingsItem.visibleCases(for: contentSections)

        return NavigationView {
            List(selection: $selectedItem) {
                ForEach(visibleItems, id: \.self) { item in
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
                if contentSections.contains(.servers) {
                    Section(
                        header: Text(L10n.Settings.ConnectionSection.serversHeader),
                        footer: Text(L10n.Settings.ConnectionSection.serversFooter)
                    ) {
                        ServersListView()
                    }
                }

                // General section
                if contentSections.contains(.general) {
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
                }

                // Integrations section
                if contentSections.contains(.integrations) {
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
                }

                // Apple Watch section (only on iPhone with paired watch)
                if shouldShowWatchSection, contentSections.contains(.watch) {
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
                if UIDevice.current.userInterfaceIdiom == .phone, contentSections.contains(.carPlay) {
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
                if contentSections.contains(.legacy) {
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
                }

                // Help section
                if contentSections.contains(.help) {
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
