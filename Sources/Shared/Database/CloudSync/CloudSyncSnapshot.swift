import CryptoKit
import Foundation

/// A portable copy of every GRDB table, produced on one device and applied on another
/// through iCloud sync.
///
/// Snapshots never contain Home Assistant credentials: tokens and webhook secrets live
/// only in the Keychain, and the `serverInfoMirror` table is sanitized before it is
/// ever written to GRDB (see `ServerInfo.mirroredForPersistence`), so a device that
/// adopts a snapshot must obtain its own token through the re-authentication flow.
public struct CloudSyncSnapshot: Codable, Equatable {
    /// Bumped when the payload format changes incompatibly; devices refuse to import
    /// snapshots written in a newer format than they understand.
    public static let currentFormatVersion = 1

    public var formatVersion: Int
    public var createdAt: Date
    public var sourceDeviceID: String
    /// Table name → rows, each row mapping column name → value.
    public var tables: [String: [[String: CloudSyncValue]]]

    public init(
        formatVersion: Int = Self.currentFormatVersion,
        createdAt: Date,
        sourceDeviceID: String,
        tables: [String: [[String: CloudSyncValue]]]
    ) {
        self.formatVersion = formatVersion
        self.createdAt = createdAt
        self.sourceDeviceID = sourceDeviceID
        self.tables = tables
    }

    /// Stable digest of the table contents, used to detect whether the local database
    /// and the cloud copy have diverged. Ignores `createdAt` and `sourceDeviceID` so
    /// identical data hashes identically on every device, and is independent of table
    /// and row ordering.
    public var contentHash: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        var hasher = SHA256()
        for tableName in tables.keys.sorted() {
            hasher.update(data: Data(tableName.utf8))
            let rows = (tables[tableName] ?? []).compactMap { row -> String? in
                guard let data = try? encoder.encode(row) else { return nil }
                return String(decoding: data, as: UTF8.self)
            }
            for row in rows.sorted() {
                hasher.update(data: Data(row.utf8))
            }
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
