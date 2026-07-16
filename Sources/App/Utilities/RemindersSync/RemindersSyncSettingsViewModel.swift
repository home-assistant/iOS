import Foundation
import Shared

@MainActor
final class RemindersSyncSettingsViewModel: ObservableObject {
    @Published var configs: [RemindersSyncConfig] = []
    @Published var authorizationState: RemindersSyncManager.AuthorizationState = .notDetermined

    func load() {
        authorizationState = RemindersSyncManager.shared.authorizationState
        configs = RemindersSyncConfig.all()
    }

    func requestAccessIfNeeded() async {
        if RemindersSyncManager.shared.authorizationState == .notDetermined {
            _ = await RemindersSyncManager.shared.requestAccess()
        }
        load()
    }

    func delete(_ config: RemindersSyncConfig) {
        config.delete()
        load()
    }

    func syncNow() {
        RemindersSyncManager.shared.syncNow()
    }
}
