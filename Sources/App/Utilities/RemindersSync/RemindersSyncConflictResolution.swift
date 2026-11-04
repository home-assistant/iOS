import Foundation
import Shared

/// Which side wins when the same linked item changed on both sides since the last sync.
/// Only consulted for two-way syncs; one-way syncs always overwrite their target side.
enum RemindersSyncConflictResolution: String, Codable, CaseIterable, Identifiable {
    case homeAssistant
    case reminders

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .homeAssistant:
            return L10n.RemindersSync.Conflict.homeAssistant
        case .reminders:
            return L10n.RemindersSync.Conflict.reminders
        }
    }
}
