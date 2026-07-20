import Foundation
import Shared

/// Global Reminders sync preferences: how often to re-fetch the Home Assistant side while the
/// app is open, how often to request background refreshes, and who wins conflicts.
/// Persisted as JSON in the app-group defaults so a future widget/extension could read it.
struct RemindersSyncSettings: Codable, Equatable {
    /// Seconds between foreground re-fetches of the Home Assistant lists. `0` disables the timer;
    /// Reminders-side changes still sync immediately via `EKEventStoreChanged`.
    var foregroundRefreshInterval: TimeInterval = 0
    /// Requested seconds between background refreshes. `0` disables scheduling. iOS treats this
    /// as the earliest allowed start, not a guarantee.
    var backgroundRefreshInterval: TimeInterval = 0
    var conflictResolution: RemindersSyncConflictResolution = .homeAssistant

    static let foregroundIntervalOptions: [TimeInterval] = [0, 60, 5 * 60, 15 * 60, 30 * 60, 60 * 60]
    static let backgroundIntervalOptions: [TimeInterval] = [
        0,
        15 * 60,
        30 * 60,
        60 * 60,
        2 * 60 * 60,
        6 * 60 * 60,
        12 * 60 * 60,
        24 * 60 * 60,
    ]

    private static let defaultsKey = "remindersSyncSettings"
    private static var defaults: UserDefaults { UserDefaults(suiteName: AppConstants.AppGroupID) ?? .standard }

    static var current: RemindersSyncSettings {
        guard let data = defaults.data(forKey: defaultsKey),
              let settings = try? JSONDecoder().decode(RemindersSyncSettings.self, from: data) else {
            return RemindersSyncSettings()
        }
        return settings
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        Self.defaults.set(data, forKey: Self.defaultsKey)
    }

    static func intervalLabel(_ interval: TimeInterval) -> String {
        guard interval > 0 else { return L10n.RemindersSync.Settings.Refresh.off }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .full
        return formatter.string(from: interval) ?? "\(Int(interval))s"
    }
}
