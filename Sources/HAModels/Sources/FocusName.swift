import Foundation
import GRDB

/// A Focus name the user creates in the app so an iOS Focus Filter can report which Focus is
/// running. iOS exposes whether _a_ Focus is active, but never which one, so the user pairs each of
/// their Focuses with one of these names in Settings › Focus › Focus Filters, and the app reports
/// the paired name as the `focus_name` sensor.
///
/// Pure, extension-safe model (Foundation + GRDB only); the `Current.database()`-backed queries
/// live in an extension in the `Shared` module.
public struct FocusName: Codable, FetchableRecord, PersistableRecord, Equatable, Identifiable, Sendable {
    public static let databaseTableName = GRDBDatabaseTable.focusName.rawValue

    public var id: String
    /// The user-visible name, reported verbatim as the state of the `focus_name` sensor.
    public var name: String

    public init(id: String = UUID().uuidString, name: String) {
        self.id = id
        self.name = name
    }
}
