import Foundation
import Shared

/// Keeps the new app's pending session across a relaunch: iOS may terminate the new app while the
/// previous app is in front, and the payload URL then cold-starts it.
enum AppMigrationSessionStore {
    private static let keychainKey = "app_migration_session"

    private struct Record: Codable {
        let id: UUID
        let key: String
    }

    static func save(_ session: AppMigrationSession) {
        guard let data = try? JSONEncoder().encode(Record(id: session.id, key: session.keyString)) else { return }
        try? AppConstants.Keychain.set(data, key: keychainKey)
    }

    static func load() -> AppMigrationSession? {
        guard let data = try? AppConstants.Keychain.getData(keychainKey),
              let record = try? JSONDecoder().decode(Record.self, from: data) else { return nil }
        return AppMigrationSession(id: record.id, keyString: record.key)
    }

    static func clear() {
        try? AppConstants.Keychain.remove(keychainKey)
    }
}
