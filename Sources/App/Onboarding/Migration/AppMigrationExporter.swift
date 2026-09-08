import Foundation
import GRDB
import KeychainAccess
import Shared

/// Packages the previous app's setup. Runs off the main thread; the database snapshot can be large.
struct AppMigrationExporter {
    /// Values the new app generates for itself and must not inherit. The push token belongs to the
    /// previous app's bundle and would be rejected for the new one.
    static let excludedDefaultsKeys: Set<String> = Set(["pushID", "FASTLANE_SNAPSHOT"])
        .union(AppMigrationHandoffStore.defaultsKeys)

    func makePayload(sessionID: UUID, grantedPermissions: [SensorPermission]) throws -> AppMigrationPayload {
        try AppMigrationPayload(
            version: AppMigrationPayload.currentVersion,
            sessionID: sessionID,
            serverNames: Current.servers.all.map(\.info.name),
            database: databaseSnapshot(),
            appGroupDefaults: defaultsSnapshot(),
            keychainItems: keychainItems(),
            grantedPermissions: grantedPermissions.map(\.rawValue)
        )
    }

    private func databaseSnapshot() throws -> Data {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("app-migration-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        let destination = try DatabaseQueue(path: url.path)
        try Current.database().backup(to: destination)
        try destination.close()
        return try Data(contentsOf: url)
    }

    private func defaultsSnapshot() throws -> Data {
        var domain = UserDefaults(suiteName: AppConstants.AppGroupID)?
            .persistentDomain(forName: AppConstants.AppGroupID) ?? [:]
        for key in Self.excludedDefaultsKeys {
            domain.removeValue(forKey: key)
        }
        return try PropertyListSerialization.data(fromPropertyList: domain, format: .binary, options: 0)
    }

    private func keychainItems() -> [AppMigrationPayload.KeychainItem] {
        AppMigrationKeychainStore.allCases.flatMap { store -> [AppMigrationPayload.KeychainItem] in
            let keychain = Keychain(service: store.service)
            return keychain.allKeys().compactMap { key in
                guard let data = try? keychain.getData(key) else { return nil }
                return AppMigrationPayload.KeychainItem(store: store, key: key, data: data)
            }
        }
    }
}
