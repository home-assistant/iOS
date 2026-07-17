import SFSafeSymbols
import Shared
import SwiftUI

struct RemindersSyncSettingsView: View {
    @StateObject private var viewModel = RemindersSyncSettingsViewModel()
    @ObservedObject private var syncManager = RemindersSyncManager.shared
    @State private var showAddSheet = false

    var body: some View {
        List {
            AppleLikeListTopRowHeader(
                image: .formatListChecksIcon,
                title: L10n.Settings.RemindersSync.title,
                subtitle: L10n.RemindersSync.Settings.subtitle
            )
            if viewModel.authorizationState == .denied {
                Section(header: Text(L10n.RemindersSync.Settings.AccessDenied.title)) {
                    Text(L10n.RemindersSync.Settings.AccessDenied.body)
                        .foregroundStyle(.secondary)
                    Button(L10n.RemindersSync.Settings.openSettings) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            } else {
                Section(header: Text(L10n.RemindersSync.Settings.SyncedLists.header)) {
                    if viewModel.configs.isEmpty {
                        Text(L10n.RemindersSync.Settings.Empty.body)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(viewModel.configs) { config in
                        VStack(alignment: .leading, spacing: DesignSystem.Spaces.half) {
                            HStack(spacing: DesignSystem.Spaces.one) {
                                Text(config.reminderListName)
                                Image(systemSymbol: config.direction.symbol)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(config.todoEntityName)
                            }
                            Text(config.direction.localizedTitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(lastSyncedText(for: config))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                viewModel.delete(config)
                            } label: {
                                Label(L10n.delete, systemSymbol: .trash)
                            }
                        }
                    }
                    Button {
                        showAddSheet = true
                    } label: {
                        Label(L10n.RemindersSync.Settings.addList, systemSymbol: .plus)
                    }
                }
                if !viewModel.configs.isEmpty {
                    Section {
                        Button {
                            viewModel.syncNow()
                        } label: {
                            if syncManager.isSyncing {
                                Label(L10n.RemindersSync.Settings.syncing, systemSymbol: .arrowTriangle2Circlepath)
                            } else {
                                Label(L10n.RemindersSync.Settings.syncNow, systemSymbol: .arrowTriangle2Circlepath)
                            }
                        }
                        .disabled(syncManager.isSyncing)
                    }
                }
                refreshSections
                conflictSection
                historySection
            }
        }
        .sheet(isPresented: $showAddSheet, onDismiss: {
            viewModel.load()
        }) {
            RemindersSyncAddView()
        }
        .onAppear {
            viewModel.load()
            Task {
                await viewModel.requestAccessIfNeeded()
            }
        }
        .onChange(of: syncManager.isSyncing) { isSyncing in
            if !isSyncing {
                viewModel.load()
            }
        }
    }

    private var refreshSections: some View {
        Group {
            Section(
                header: Text(L10n.RemindersSync.Settings.Refresh.header),
                footer: Text(L10n.RemindersSync.Settings.Refresh.foregroundFooter)
            ) {
                Picker(
                    L10n.RemindersSync.Settings.Refresh.foreground,
                    selection: $viewModel.settings.foregroundRefreshInterval
                ) {
                    ForEach(RemindersSyncSettings.foregroundIntervalOptions, id: \.self) { interval in
                        Text(RemindersSyncSettings.intervalLabel(interval)).tag(interval)
                    }
                }
            }
            Section(
                header: Text(L10n.RemindersSync.Settings.Refresh.backgroundHeader),
                footer: Text(L10n.RemindersSync.Settings.Refresh.backgroundFooter)
            ) {
                Picker(
                    L10n.RemindersSync.Settings.Refresh.background,
                    selection: $viewModel.settings.backgroundRefreshInterval
                ) {
                    ForEach(RemindersSyncSettings.backgroundIntervalOptions, id: \.self) { interval in
                        Text(RemindersSyncSettings.intervalLabel(interval)).tag(interval)
                    }
                }
            }
        }
        .onChange(of: viewModel.settings) { _ in
            viewModel.saveSettings()
        }
    }

    private var conflictSection: some View {
        Section(
            header: Text(L10n.RemindersSync.Settings.Conflicts.header),
            footer: Text(L10n.RemindersSync.Settings.Conflicts.footer)
        ) {
            Picker(
                L10n.RemindersSync.Settings.Conflicts.title,
                selection: $viewModel.settings.conflictResolution
            ) {
                ForEach(RemindersSyncConflictResolution.allCases) { resolution in
                    Text(resolution.localizedTitle).tag(resolution)
                }
            }
        }
    }

    private var historySection: some View {
        Section {
            NavigationLink {
                RemindersSyncHistoryView()
            } label: {
                Label(L10n.RemindersSync.History.title, systemSymbol: .clockArrowCirclepath)
            }
        }
    }

    private func lastSyncedText(for config: RemindersSyncConfig) -> String {
        guard let lastSyncDate = config.lastSyncDate else {
            return L10n.RemindersSync.Settings.neverSynced
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return L10n.RemindersSync.Settings
            .lastSynced(formatter.localizedString(for: lastSyncDate, relativeTo: Current.date()))
    }
}

extension RemindersSyncSettingsView: SettingsScreenSearchable {
    static var settingsSearchEntries: [SettingsSearchEntry] {
        [
            SettingsSearchEntry(L10n.RemindersSync.Settings.addList),
            SettingsSearchEntry(L10n.RemindersSync.Settings.syncNow),
        ]
    }
}

#Preview {
    NavigationView {
        RemindersSyncSettingsView()
    }
}
