import Foundation
import Shared

@MainActor
final class RemindersSyncSettingsViewModel: ObservableObject {
    @Published var configs: [RemindersSyncConfig] = []
    @Published var authorizationState: RemindersSyncManager.AuthorizationState = .notDetermined
    @Published var settings: RemindersSyncSettings = .current

    func load() {
        authorizationState = RemindersSyncManager.shared.authorizationState
        configs = RemindersSyncConfig.all()
        settings = .current
    }

    func saveSettings() {
        settings.save()
        RemindersSyncManager.shared.settingsChanged()
    }

    func requestAccessIfNeeded() async {
        if RemindersSyncManager.shared.authorizationState == .notDetermined {
            _ = await RemindersSyncManager.shared.requestAccess()
        }
        load()
    }

    func delete(_ config: RemindersSyncConfig) {
        config.delete()
        // With no configs left the scheduled background refresh should be cancelled.
        RemindersSyncBackgroundRefresher.schedule()
        load()
    }

    func syncNow() {
        RemindersSyncManager.shared.syncNow()
    }
}
