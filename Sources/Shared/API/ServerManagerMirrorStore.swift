import Foundation
import GRDB

private struct ServerInfoMirrorRecord: Codable, FetchableRecord, PersistableRecord {
    static var databaseTableName: String { GRDBDatabaseTable.serverInfoMirror.rawValue }

    var id: String
    var serverInfoJSON: ServerInfo
}

// Stores a sanitized mirror of server metadata in GRDB so the app can recover the
// server list even if Keychain data is lost during the developer-account migration.
final class ServerManagerGRDBMirrorStore: ServerManagerMirrorStore {
    func removeAll() {
        do {
            try Current.database().write { db in
                _ = try ServerInfoMirrorRecord.deleteAll(db)
            }
        } catch {
            Current.Log.error("failed to clear mirrored server info: \(error)")
        }
    }

    func allKeys() -> [String] {
        allServerInfo().map(\.0)
    }

    func allServerInfo() -> [(String, ServerInfo)] {
        do {
            return try Current.database().read { db in
                try ServerInfoMirrorRecord
                    .fetchAll(db)
                    .map { ($0.id, $0.serverInfoJSON) }
            }
        } catch {
            Current.Log.error("failed to fetch mirrored server info: \(error)")
            return []
        }
    }

    func getServerInfo(_ key: String) -> ServerInfo? {
        do {
            return try Current.database().read { db in
                try ServerInfoMirrorRecord.fetchOne(db, key: key)?.serverInfoJSON
            }
        } catch {
            Current.Log.error("failed to fetch mirrored server info for \(key): \(error)")
            return nil
        }
    }

    func set(_ serverInfo: ServerInfo, key: String) {
        let record = ServerInfoMirrorRecord(id: key, serverInfoJSON: serverInfo.mirroredForPersistence)

        do {
            try Current.database().write { db in
                try record.insert(db, onConflict: .replace)
            }
        } catch {
            Current.Log.error("failed to persist mirrored server info for \(key): \(error)")
        }
    }

    func remove(_ key: String) {
        do {
            try Current.database().write { db in
                _ = try ServerInfoMirrorRecord.deleteOne(db, key: key)
            }
        } catch {
            Current.Log.error("failed to delete mirrored server info for \(key): \(error)")
        }
    }
}
