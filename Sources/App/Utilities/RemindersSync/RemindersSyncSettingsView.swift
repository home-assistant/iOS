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
            }
        }
        .navigationTitle(L10n.Settings.RemindersSync.title)
        .navigationBarTitleDisplayMode(.inline)
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
