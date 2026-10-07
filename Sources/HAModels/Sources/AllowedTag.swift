import Foundation
import GRDB

/// An NFC/QR tag identifier the user has approved for use. The `Current.database()`-backed
/// queries live in an extension in the `Shared` module.
public struct AllowedTag: Codable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = GRDBDatabaseTable.allowedTags.rawValue

    public var tag: String

    public init(tag: String) {
        self.tag = tag
    }
}
