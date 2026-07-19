import Foundation
import GRDB

/// One recorded Reminders sync run for a list pairing: when it happened, whether it succeeded
/// and what it changed. Runs that change nothing aren't recorded. Pure, extension-safe model;
/// the `Current.database()`-backed queries live in an extension in the `Shared` module.
public struct RemindersSyncHistoryEntry: Codable, FetchableRecord, PersistableRecord, Equatable, Identifiable,
    Sendable {
    public static let databaseTableName = GRDBDatabaseTable.remindersSyncHistoryEntry.rawValue

    public var id: String
    public var configId: String
    /// Display label of the pairing, e.g. `Groceries ↔ Shopping list`, captured at sync time so
    /// history stays readable after the config is deleted.
    public var listLabel: String
    public var date: Date
    public var success: Bool
    public var error: String?
    /// Newline-separated, localized lines describing each applied change.
    public var details: String

    public var detailLines: [String] {
        details.split(separator: "\n").map(String.init)
    }

    public init(
        id: String,
        configId: String,
        listLabel: String,
        date: Date,
        success: Bool,
        error: String?,
        details: String
    ) {
        self.id = id
        self.configId = configId
        self.listLabel = listLabel
        self.date = date
        self.success = success
        self.error = error
        self.details = details
    }
}
