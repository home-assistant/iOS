import Foundation
import SFSafeSymbols
import Shared

extension RemindersSyncDirection {
    var localizedTitle: String {
        switch self {
        case .bothWays: return L10n.RemindersSync.Direction.bothWays
        case .toHomeAssistant: return L10n.RemindersSync.Direction.toHomeAssistant
        case .toReminders: return L10n.RemindersSync.Direction.toReminders
        }
    }

    /// Arrow between the Reminders list (leading) and the Home Assistant list (trailing).
    var symbol: SFSymbol {
        switch self {
        case .bothWays: return .arrowLeftArrowRight
        case .toHomeAssistant: return .arrowRight
        case .toReminders: return .arrowLeft
        }
    }
}
