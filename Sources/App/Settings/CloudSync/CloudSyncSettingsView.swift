import SFSafeSymbols
import Shared
import SwiftUI

struct CloudSyncSettingsView: View {
    @StateObject private var viewModel = CloudSyncSettingsViewModel()
    @ObservedObject private var syncManager = CloudSyncManager.shared

    var body: some View {
        List {
            AppleLikeListTopRowHeader(
                image: .cloudSyncIcon,
                title: L10n.SettingsDetails.CloudSync.title,
                subtitle: L10n.SettingsDetails.CloudSync.subtitle
            )
            toggleSection
            if viewModel.isEnabled {
                statusSection
                deleteSection
            }
        }
        .animation(.default, value: viewModel.isEnabled)
    }

    private var toggleSection: some View {
        Section(footer: Text(L10n.SettingsDetails.CloudSync.footer)) {
            Toggle(isOn: toggleBinding) {
                Text(L10n.SettingsDetails.CloudSync.toggle)
            }
            .alert(
                L10n.SettingsDetails.CloudSync.EnableWarning.title,
                isPresented: $viewModel.showEnableWarning
            ) {
                Button(L10n.SettingsDetails.CloudSync.EnableWarning.confirm) {
                    Task { await viewModel.confirmEnable() }
                }
                Button(L10n.cancelLabel, role: .cancel) {}
            } message: {
                Text(L10n.SettingsDetails.CloudSync.EnableWarning.message)
            }
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var statusSection: some View {
        Section {
            Button {
                syncManager.syncNow()
            } label: {
                if syncManager.isSyncing {
                    Label(L10n.SettingsDetails.CloudSync.syncing, systemSymbol: .arrowTriangle2Circlepath)
                } else {
                    Label(L10n.SettingsDetails.CloudSync.syncNow, systemSymbol: .arrowTriangle2Circlepath)
                }
            }
            .disabled(syncManager.isSyncing)
            Text(lastSyncedText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var deleteSection: some View {
        Section {
            DeleteCloudDataButton {
                viewModel.disable()
                await viewModel.deleteCloudData()
            }
        }
    }

    private var toggleBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isEnabled },
            set: { newValue in
                if newValue {
                    viewModel.requestEnable()
                } else {
                    viewModel.disable()
                }
            }
        )
    }

    private var errorMessage: String? {
        viewModel.enableError ?? (viewModel.isEnabled ? syncManager.lastErrorMessage : nil)
    }

    private var lastSyncedText: String {
        guard let lastSyncDate = syncManager.lastSyncDate else {
            return L10n.SettingsDetails.CloudSync.neverSynced
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return L10n.SettingsDetails.CloudSync
            .lastSynced(formatter.localizedString(for: lastSyncDate, relativeTo: Current.date()))
    }
}

extension CloudSyncSettingsView: SettingsScreenSearchable {
    static var settingsSearchEntries: [SettingsSearchEntry] {
        [
            SettingsSearchEntry(L10n.SettingsDetails.CloudSync.toggle),
            SettingsSearchEntry(L10n.SettingsDetails.CloudSync.syncNow),
            SettingsSearchEntry(L10n.SettingsDetails.CloudSync.deleteCloudData),
        ]
    }
}

#Preview {
    NavigationView {
        CloudSyncSettingsView()
    }
}
