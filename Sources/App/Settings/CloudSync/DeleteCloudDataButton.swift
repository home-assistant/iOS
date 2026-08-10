import SFSafeSymbols
import Shared
import SwiftUI

/// Destructive action that turns iCloud sync off and removes the synced snapshot from
/// the user's private iCloud database. The confirmation dialog is attached directly to
/// the button, per the app's confirmation-ownership convention.
struct DeleteCloudDataButton: View {
    let action: () async -> Void

    @State private var showConfirmation = false

    var body: some View {
        Button(role: .destructive) {
            showConfirmation = true
        } label: {
            Label(L10n.SettingsDetails.CloudSync.deleteCloudData, systemSymbol: .trash)
                .foregroundStyle(.red)
        }
        .confirmationDialog(
            L10n.SettingsDetails.CloudSync.DeleteConfirmation.title,
            isPresented: $showConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.SettingsDetails.CloudSync.DeleteConfirmation.confirm, role: .destructive) {
                Task { await action() }
            }
            Button(L10n.cancelLabel, role: .cancel) {}
        } message: {
            Text(L10n.SettingsDetails.CloudSync.DeleteConfirmation.message)
        }
    }
}

#Preview {
    List {
        DeleteCloudDataButton {}
    }
}
