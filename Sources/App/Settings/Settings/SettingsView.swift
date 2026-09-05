import Shared
import SwiftUI

struct SettingsView: View {
    private enum Constants {
        static let macSidebarRowHeight: CGFloat = 32
        static let macSidebarBottomPadding: CGFloat = DesignSystem.Spaces.three
    }

    var embedInOwnNavigation: Bool = true

    @State private var macSidebarSelection: MacSettingsSidebarSelection? = .item(.general)
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
            macOSDetail
        }
        .navigationViewStyle(.columns)
    }

    @ViewBuilder
    private var macOSDetail: some View {
        switch macSidebarSelection {
        case let .item(item):
            item.destinationView
        case let .server(identifier):
            if let server = serversObserver.servers.first(where: { $0.identifier == identifier }) {
                ConnectionSettingsView(server: server)
            } else {
                macOSPlaceholder
            }
        case .serverSwitching:
            ServerSwitchingSettingsView()
        case nil:
            macOSPlaceholder
        }
    }

    private var macOSSidebarContent: some View {
        List(selection: $macSidebarSelection) {
            if isSearching {
                searchResultsContent
            } else {
                AppMigrationSettingsSection()

                // Servers section
                settingsSection(header: L10n.Settings.ConnectionSection.serversHeader) {
                    ServersListView(macSidebarSelection: macSidebarSelection)
                }

                if isShowingTranslationKeys {
                    translationKeysWarningSection
                }

                // Settings items grouped by user objective
                settingsSections(matching: nil)
            }
            Color.clear
                .frame(height: Constants.macSidebarBottomPadding)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .environment(\.defaultMinListRowHeight, Constants.macSidebarRowHeight)
        .labelStyle(MacSettingsSidebarLabelStyle())
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .secondarySystemBackground).ignoresSafeArea())
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

    // When pushed onto the container's stack (`embedInOwnNavigation == false`) items are pushed as
    // `AppSettingsPushRoute.item` instead, resolved by `ConditionalContainerView`: that path must stay
    // single-typed or SwiftUI's path diffing can fatally error comparing elements of different types.
    @ViewBuilder
    private var iOSView: some View {
        if embedInOwnNavigation {
            NavigationStack {
                iOSListContent
                    .navigationDestination(for: SettingsItem.self) { item in
                        item.destinationView
                    }
            }
        } else {
            iOSListContent
        }
    }

    private var iOSListContent: some View {
        List {
            if isSearching {
                searchResultsContent
            } else {
                AppMigrationSettingsSection()

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
        .accessibilityIdentifier(AccessibilityIdentifier.settingsList.rawValue)
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
        if !serverSearchResults.isEmpty {
            return true
        }
        return SettingsSection.allCases.contains { !$0.items(matching: trimmedSearchQuery).isEmpty }
    }

    private var serverConnectionContentMatches: [SettingsSearchEntry] {
        guard isSearching else { return [] }
        return ConnectionSettingsView.settingsSearchEntries.filter { $0.matches(searchQuery: trimmedSearchQuery) }
    }

    private var serverSearchResults: [Server] {
        guard isSearching else { return [] }
        if !serverConnectionContentMatches.isEmpty {
            return serversObserver.servers
        }
        return serversObserver.servers.filter { $0.info.name.localizedStandardContains(trimmedSearchQuery) }
    }

    private var serverContentSubtitle: String? {
        let matched = serverConnectionContentMatches
        guard !matched.isEmpty else { return nil }
        return matched.prefix(3).map(\.title).joined(separator: ", ")
    }

    @ViewBuilder
    private var searchResultsContent: some View {
        if hasSearchResults {
            // Servers live in their own list normally (including the Catalyst sidebar, where the
            // item is not "visible"), so surface them as plain rows when searching: the servers
            // screen itself plus every server whose name or connection settings match the query.
            let serverResults = serverSearchResults
            if SettingsItem.servers.matches(searchQuery: trimmedSearchQuery) || !serverResults.isEmpty {
                Section {
                    if SettingsItem.servers.matches(searchQuery: trimmedSearchQuery) {
                        settingsItemRow(.servers, searchQuery: trimmedSearchQuery)
                    }
                    ForEach(serverResults, id: \.identifier) { server in
                        NavigationLink(destination: ConnectionSettingsView(server: server)) {
                            serverSearchRow(server: server)
                        }
                        .tag(MacSettingsSidebarSelection.server(server.identifier))
                        .macSettingsSidebarRow(isSelected: macSidebarSelection == .server(server.identifier))
                    }
                }
            }
            settingsSections(matching: trimmedSearchQuery)
        } else {
            noSearchResultsSection
        }
    }

    private func serverSearchRow(server: Server) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
            HomeAssistantAccountRowView(server: server, isCompact: Current.isCatalyst)
            if let serverContentSubtitle {
                Text(serverContentSubtitle)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private func settingsSections(matching searchQuery: String?) -> some View {
        ForEach(SettingsSection.allCases, id: \.self) { section in
            let items = searchQuery.map { section.items(matching: $0) } ?? section.items
            if !items.isEmpty {
                settingsSection(header: section.header) {
                    ForEach(items, id: \.self) { item in
                        settingsItemRow(item, searchQuery: searchQuery)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func settingsSection(
        header: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        if Current.isCatalyst {
            Section {
                Text(header)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, DesignSystem.Spaces.two)
                    .padding(.bottom, DesignSystem.Spaces.half)
                    .listRowInsets(EdgeInsets(
                        top: 0,
                        leading: DesignSystem.Spaces.two,
                        bottom: 0,
                        trailing: DesignSystem.Spaces.two
                    ))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .accessibilityAddTraits(.isHeader)
                content()
            }
        } else {
            Section(header: Text(header)) {
                content()
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
            .macSettingsSidebarRow()
        } else if Current.isCatalyst {
            // The Catalyst sidebar lives in a `NavigationView`, which value-based links don't
            // support, so it keeps the eager destination.
            NavigationLink(destination: item.destinationView) {
                settingsItemLabel(item, subtitle: subtitle)
            }
            .tag(MacSettingsSidebarSelection.item(item))
            .macSettingsSidebarRow(isSelected: macSidebarSelection == .item(item))
        } else if embedInOwnNavigation {
            // Value-based, resolved by `navigationDestination(for:)` in `iOSView`, so
            // `item.destinationView` — and every destination's stored properties with it — is only
            // constructed on navigation instead of for every row on every list evaluation.
            NavigationLink(value: item) {
                settingsItemLabel(item, subtitle: subtitle)
            }
        } else {
            // Pushed onto the container's stack, whose path must stay `AppSettingsPushRoute`-typed.
            NavigationLink(value: AppSettingsPushRoute.item(item)) {
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
                        .fontWeight(macSidebarSelection == .item(item) ? .semibold : .regular)
                        .lineLimit(Current.isCatalyst ? 1 : nil)
                    if item == .complications || item == .remindersSync {
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
            if Current.isCatalyst {
                item.icon(size: MacSettingsSidebarLabelStyle.iconSize)
            } else {
                item.icon
            }
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
