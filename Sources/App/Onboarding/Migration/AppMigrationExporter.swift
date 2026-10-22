import Foundation
import GRDB
import HAModels
import HANetworking
import KeychainAccess
import Shared

/// Packages the previous app's setup. Runs off the main thread; the database snapshot can be large.
struct AppMigrationExporter {
    /// Values the new app generates for itself and must not inherit. The push token belongs to the
    /// previous app's bundle and would be rejected for the new one.
    static let excludedDefaultsKeys: Set<String> = Set(["pushID", "FASTLANE_SNAPSHOT"])
        .union(AppMigrationHandoffStore.defaultsKeys)

    /// Server caches the new app refills on its first connection, and histories not worth carrying:
    /// dropped from the snapshot so a large home does not become a large pasteboard.
    static let regeneratedTables: [GRDBDatabaseTable] = [
        .HAAppEntity,
        .appEntityRegistryListForDisplay,
        .displayEntityRegistry,
        .deviceRegistry,
        .appPanel,
        .appArea,
        .locationHistory,
        .locationError,
        .remindersSyncHistoryEntry,
        .clientEvent,
    ]

    func makePayload(sessionID: UUID, grantedPermissions: [SensorPermission]) throws -> AppMigrationPayload {
        try AppMigrationPayload(
            version: AppMigrationPayload.currentVersion,
            sessionID: sessionID,
            serverNames: Current.servers.all.map(\.info.name),
            database: databaseSnapshot(),
            appGroupDefaults: defaultsSnapshot(),
            keychainItems: keychainItems(),
            grantedPermissions: grantedPermissions.map(\.rawValue),
            clientCertificates: clientCertificates()
        )
    }

    private func databaseSnapshot() throws -> Data {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("app-migration-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        let destination = try DatabaseQueue(path: url.path)
        try Current.database().backup(to: destination)
        try destination.write { db in
            for table in Self.regeneratedTables where try db.tableExists(table.rawValue) {
                try db.execute(sql: "DELETE FROM \(table.rawValue)")
            }
        }
        try destination.vacuum()
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

    /// A server's identity that cannot be exported fails the whole transfer: the new app would have
    /// the server without a way to authenticate, and the user would be offered to erase the only
    /// copy of the key.
    private func clientCertificates() throws -> [AppMigrationPayload.ClientCertificateItem] {
        let manager = ClientCertificateManager.shared
        var seen = Set<String>()
        return try Current.servers.all.compactMap { server in
            guard let certificate = server.info.connection.clientCertificate,
                  seen.insert(certificate.keychainIdentifier).inserted else { return nil }
            if let transfer = manager.transferMaterial(for: certificate.keychainIdentifier) {
                return .init(keychainIdentifier: certificate.keychainIdentifier, transfer: transfer, identity: nil)
            }
            let identity = try manager.exportIdentity(for: certificate.keychainIdentifier)
            return .init(keychainIdentifier: certificate.keychainIdentifier, transfer: nil, identity: identity)
        }
    }

    private func keychainItems() -> [AppMigrationPayload.KeychainItem] {
        AppMigrationKeychainStore.transferred.flatMap { store -> [AppMigrationPayload.KeychainItem] in
            let keychain = Keychain(service: store.service)
            return keychain.allKeys().compactMap { key in
                guard let data = try? keychain.getData(key) else { return nil }
                return AppMigrationPayload.KeychainItem(store: store, key: key, data: data)
            }
        }
    }
}
