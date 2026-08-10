import Foundation
import Shared

@MainActor
final class CloudSyncSettingsViewModel: ObservableObject {
    @Published var isEnabled = Current.settingsStore.iCloudSyncEnabled
    /// Shown before anything is synced: the user must acknowledge that this device's
    /// app data will be shared with their other iCloud devices.
    @Published var showEnableWarning = false
    @Published var enableError: String?

    func requestEnable() {
        showEnableWarning = true
    }

    func confirmEnable() async {
        do {
            try await CloudSyncManager.shared.enable()
            enableError = nil
            isEnabled = true
        } catch {
            enableError = error.localizedDescription
            isEnabled = false
        }
    }

    func disable() {
        CloudSyncManager.shared.disable()
        isEnabled = false
    }

    func deleteCloudData() async {
        do {
            try await CloudSyncManager.shared.deleteCloudData()
            enableError = nil
        } catch {
            enableError = error.localizedDescription
        }
    }
}
