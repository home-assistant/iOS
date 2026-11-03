import Foundation
import Shared

@MainActor
final class RemindersSyncSettingsViewModel: ObservableObject {
    @Published var configs: [RemindersSyncConfig] = []
    @Published var authorizationState: RemindersSyncManager.AuthorizationState = .notDetermined
    @Published var settings: RemindersSyncSettings

    /// Where the Reminders authorization state and the saved settings come from. Snapshot tests
    /// inject fixed values, since the test host's EventKit permission and app-group defaults vary
    /// between machines.
    private let currentAuthorizationState: @MainActor () -> RemindersSyncManager.AuthorizationState
    private let currentSettings: @MainActor () -> RemindersSyncSettings

    init(
        authorizationState: @escaping @MainActor () -> RemindersSyncManager.AuthorizationState = {
            RemindersSyncManager.shared.authorizationState
        },
        settings: @escaping @MainActor () -> RemindersSyncSettings = { .current }
    ) {
        self.currentAuthorizationState = authorizationState
        self.currentSettings = settings
        self.settings = settings()
    }

    func load() {
        authorizationState = currentAuthorizationState()
        configs = RemindersSyncConfig.all()
        settings = currentSettings()
    }

    func saveSettings() {
        settings.save()
        RemindersSyncManager.shared.settingsChanged()
    }

    func requestAccessIfNeeded() async {
        if currentAuthorizationState() == .notDetermined {
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
