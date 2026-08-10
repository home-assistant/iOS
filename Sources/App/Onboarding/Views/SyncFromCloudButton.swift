import Shared
import SwiftUI

/// Onboarding entry point for iCloud sync: downloads the app data another device
/// already synced to the user's iCloud account and enables syncing on this device, so
/// a second device doesn't have to be configured by hand. Tokens never sync, so after
/// a successful restore the container routes to the re-authentication flow for the
/// restored servers.
struct SyncFromCloudButton: View {
    private enum ResultAlert {
        case noDataFound
        case failed(String)

        var title: String {
            switch self {
            case .noDataFound: return L10n.Onboarding.CloudSync.NoData.title
            case .failed: return L10n.Onboarding.CloudSync.Error.title
            }
        }

        var message: String {
            switch self {
            case .noDataFound: return L10n.Onboarding.CloudSync.NoData.message
            case let .failed(message): return message
            }
        }
    }

    @State private var showWarning = false
    @State private var isRestoring = false
    @State private var resultAlert: ResultAlert?
    @State private var showResultAlert = false

    var body: some View {
        Button {
            showWarning = true
        } label: {
            if isRestoring {
                ProgressView()
                    .progressViewStyle(.circular)
                    .frame(maxWidth: .infinity)
            } else {
                Text(L10n.Onboarding.CloudSync.button)
            }
        }
        .tint(Color.haPrimary)
        .buttonStyle(.secondaryButton)
        .disabled(isRestoring)
        .alert(
            L10n.Onboarding.CloudSync.Warning.title,
            isPresented: $showWarning
        ) {
            Button(L10n.Onboarding.CloudSync.Warning.confirm) {
                Task { await restore() }
            }
            Button(L10n.cancelLabel, role: .cancel) {}
        } message: {
            Text(L10n.Onboarding.CloudSync.Warning.message)
        }
        .alert(
            resultAlert?.title ?? "",
            isPresented: $showResultAlert
        ) {
            Button(L10n.okLabel, role: .cancel) {}
        } message: {
            Text(resultAlert?.message ?? "")
        }
    }

    private func restore() async {
        isRestoring = true
        defer { isRestoring = false }

        do {
            if try await CloudSyncManager.shared.restoreFromCloud() {
                // Same hand-off as finishing onboarding: the container re-evaluates and
                // shows re-auth for the restored servers (or stays in onboarding when
                // the snapshot carried no servers, with the configuration now applied).
                Current.sceneManager.appCoordinator.done { coordinator in
                    coordinator.setup()
                }
            } else {
                resultAlert = .noDataFound
                showResultAlert = true
            }
        } catch {
            Current.Log.error("Onboarding iCloud restore failed: \(error)")
            resultAlert = .failed(error.localizedDescription)
            showResultAlert = true
        }
    }
}

#Preview {
    SyncFromCloudButton()
        .padding()
}
