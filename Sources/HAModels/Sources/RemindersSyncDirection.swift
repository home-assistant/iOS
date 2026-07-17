import Foundation
import GRDB

/// Which way items flow between an Apple Reminders list and a Home Assistant todo list.
public enum RemindersSyncDirection: String, Codable, CaseIterable, Identifiable, DatabaseValueConvertible {
    /// Changes on either side are propagated to the other. When the same item changed on both
    /// sides since the last sync, the Home Assistant copy wins (the server is the shared source
    /// of truth for the household and doesn't expose per-item modification times to compare).
    case bothWays
    /// Reminders is the source: its items are mirrored into the Home Assistant list.
    case toHomeAssistant
    /// Home Assistant is the source: its items are mirrored into the Reminders list.
    case toReminders

    public var id: String { rawValue }
}
