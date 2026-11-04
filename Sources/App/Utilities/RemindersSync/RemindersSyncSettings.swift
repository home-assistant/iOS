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
    /// Whether items that are already completed on one side, and were never linked, are copied to
    /// the other side as completed. Off by default: most lists carry a long tail of checked-off
    /// history that nobody wants mirrored. Completion of linked items always syncs regardless.
    var includeCompletedItems = false

    init(
        foregroundRefreshInterval: TimeInterval = 0,
        backgroundRefreshInterval: TimeInterval = 0,
        conflictResolution: RemindersSyncConflictResolution = .homeAssistant,
        includeCompletedItems: Bool = false
    ) {
        self.foregroundRefreshInterval = foregroundRefreshInterval
        self.backgroundRefreshInterval = backgroundRefreshInterval
        self.conflictResolution = conflictResolution
        self.includeCompletedItems = includeCompletedItems
    }

    /// Every key is optional on decode so a setting added in a later build doesn't reset the
    /// ones a user already saved.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.foregroundRefreshInterval = try container.decodeIfPresent(
            TimeInterval.self,
            forKey: .foregroundRefreshInterval
        ) ?? 0
        self.backgroundRefreshInterval = try container.decodeIfPresent(
            TimeInterval.self,
            forKey: .backgroundRefreshInterval
        ) ?? 0
        self.conflictResolution = try container.decodeIfPresent(
            RemindersSyncConflictResolution.self,
            forKey: .conflictResolution
        ) ?? .homeAssistant
        self.includeCompletedItems = try container.decodeIfPresent(Bool.self, forKey: .includeCompletedItems) ?? false
    }

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
