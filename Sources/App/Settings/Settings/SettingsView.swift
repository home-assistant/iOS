import Shared
import SwiftUI

struct SettingsView: View {
    var embedInOwnNavigation: Bool = true

    @State private var selectedItem: SettingsItem? = .general
    @State private var showAbout = false
    @State private var whatsNewRelease: WhatsNewRelease?
    @State private var testFlightMessage: TestFlightMessage?
    @State private var isShowingTranslationKeys = prefs.bool(forKey: "showTranslationKeys")
    @State private var searchText = ""
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
        .onAppear {
            isShowingTranslationKeys = prefs.bool(forKey: "showTranslationKeys")
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
            if isSearching {
                searchResultsContent
            } else {
                // Servers section
                Section(header: Text(L10n.Settings.ConnectionSection.serversHeader)) {
                    ServersListView()
                }

                if isShowingTranslationKeys {
                    translationKeysWarningSection
                }

                // Settings items grouped by user objective
                settingsSections(matching: nil)
            }
        }
        .searchable(text: $searchText, prompt: Text(L10n.Settings.Search.prompt))
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
        if embedInOwnNavigation {
            NavigationStack {
                iOSNavigationContent
            }
        } else {
            iOSNavigationContent
        }
    }

    private var iOSNavigationContent: some View {
        iOSListContent
            .navigationDestination(for: SettingsItem.self) { item in
                item.destinationView
            }
    }

    private var iOSListContent: some View {
        List {
            if isSearching {
                searchResultsContent
            } else {
                // Servers section
                Section(
                    header: Text(L10n.Settings.ConnectionSection.serversHeader),
                    footer: Text(L10n.Settings.ConnectionSection.serversReorderFooter)
                ) {
                    ServersListView()
                }
                .environment(\.defaultMinListRowHeight, 60)

                if isShowingTranslationKeys {
                    translationKeysWarningSection
                }

                // Settings items grouped by user objective
                settingsSections(matching: nil)

                if let latestRelease = WhatsNewEngine().latestRelease() {
                    // What's New
                    Section {
                        Button {
                            whatsNewRelease = latestRelease
                        } label: {
                            settingsItemLabel(.whatsNew)
                        }
                    }
                }

                if let latestMessage = TestFlightCommunicationEngine().latestMessage() {
                    // Beta Tester Updates
                    Section {
                        Button {
                            testFlightMessage = latestMessage
                        } label: {
                            Label {
                                Text(L10n.Settings.TestFlightCommunication.title)
                            } icon: {
                                Image(systemSymbol: .testtube2)
                            }
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
        }
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: Text(L10n.Settings.Search.prompt)
        )
        .navigationTitle(L10n.Settings.NavigationBar.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if embedInOwnNavigation, !Current.sceneManager.supportsMultipleScenes || !Current.isCatalyst {
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
            NavigationStack {
                aboutViewContent
            }
        }
        .sheet(item: $whatsNewRelease) { release in
            WhatsNewView(release: release) {
                WhatsNewEngine().markSeen(release)
            }
        }
        .sheet(item: $testFlightMessage) { message in
            TestFlightCommunicationView(message: message) {
                TestFlightCommunicationEngine().markSeen(message)
            }
        }
    }

    private var translationKeysWarningSection: some View {
        Section {
            VStack(alignment: .leading, spacing: DesignSystem.Spaces.two) {
                Label {
                    Text(verbatim: "Translation keys are visible")
                        .font(.headline)
                } icon: {
                    Image(systemSymbol: .exclamationmarkTriangleFill)
                        .foregroundColor(.orange)
                }

                Text(
                    verbatim: "Debug strings is enabled, so app text is showing localization keys instead of translated labels."
                )
                .font(.subheadline)
                .foregroundColor(.secondary)

                Button {
                    disableTranslationKeys()
                } label: {
                    Text(verbatim: "Disable debug strings")
                }
            }
            .padding(.vertical, DesignSystem.Spaces.one)
        }
    }

    private func disableTranslationKeys() {
        prefs.set(false, forKey: "showTranslationKeys")
        isShowingTranslationKeys = false
    }

    // MARK: - Sections & Search

    private var trimmedSearchQuery: String {
        searchText.trimmingCharacters(in: .whitespaces)
    }

    private var isSearching: Bool {
        !trimmedSearchQuery.isEmpty
    }

    private var hasSearchResults: Bool {
        if SettingsItem.servers.matches(searchQuery: trimmedSearchQuery) {
            return true
        }
        return SettingsSection.allCases.contains { !$0.items(matching: trimmedSearchQuery).isEmpty }
    }

    @ViewBuilder
    private var searchResultsContent: some View {
        if hasSearchResults {
            // Servers live in their own list normally (including the Catalyst sidebar, where the
            // item is not "visible"), so surface them as a plain row when searching.
            if SettingsItem.servers.matches(searchQuery: trimmedSearchQuery) {
                Section {
                    settingsItemRow(.servers, searchQuery: trimmedSearchQuery)
                }
            }
            settingsSections(matching: trimmedSearchQuery)
        } else {
            noSearchResultsSection
        }
    }

    @ViewBuilder
    private func settingsSections(matching searchQuery: String?) -> some View {
        ForEach(SettingsSection.allCases, id: \.self) { section in
            let items = searchQuery.map { section.items(matching: $0) } ?? section.items
            if !items.isEmpty {
                Section(header: Text(section.header)) {
                    ForEach(items, id: \.self) { item in
                        settingsItemRow(item, searchQuery: searchQuery)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func settingsItemRow(_ item: SettingsItem, searchQuery: String? = nil) -> some View {
        let subtitle = searchQuery.flatMap { item.contentMatchesSubtitle(searchQuery: $0) }
        if item == .help {
            Button {
                if let url = URL(string: "https://companion.home-assistant.io") {
                    openURLInBrowser(url, viewControllerProvider.viewController)
                }
            } label: {
                HStack {
                    settingsItemLabel(item, subtitle: subtitle)
                    Spacer()
                    item.accessoryIcon
                }
            }
        } else {
            NavigationLink(destination: item.destinationView) {
                settingsItemLabel(item, subtitle: subtitle)
            }
        }
    }

    private var noSearchResultsSection: some View {
        Section {
            VStack(spacing: DesignSystem.Spaces.two) {
                Image(systemSymbol: .magnifyingglass)
                    .font(.title2)
                    .foregroundColor(.secondary)
                Text(L10n.Settings.Search.NoResults.title(trimmedSearchQuery))
                    .font(.headline)
                Text(L10n.Settings.Search.NoResults.subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .padding(.vertical, DesignSystem.Spaces.two)
        }
        .listRowBackground(Color.clear)
    }

    private func settingsItemLabel(_ item: SettingsItem, subtitle: String? = nil) -> some View {
        Label {
            VStack(alignment: .leading) {
                HStack(spacing: DesignSystem.Spaces.one) {
                    Text(item.title)
                    if item == .liveActivities || item == .complications {
                        LabsLabel()
                    }
                }
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
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
}

#Preview {
    SettingsView()
        .injectingViewControllerProvider()
}
