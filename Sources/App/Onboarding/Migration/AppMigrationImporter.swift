import Foundation
import GRDB
import HANetworking
import KeychainAccess
import Shared

/// Applies a payload inside the new app: database first, then preferences, keychain items and
/// finally the servers, which go through the server manager so its cache and mirror stay in step.
struct AppMigrationImporter {
    func apply(_ payload: AppMigrationPayload) throws -> AppMigrationSummary {
        guard payload.version == AppMigrationPayload.currentVersion else {
            throw AppMigrationError.unsupportedVersion
        }
        try restoreDatabase(payload.database)
        try restoreDefaults(payload.appGroupDefaults)
        restoreKeychain(payload.keychainItems.filter { $0.store != .servers })
        let serverNames = try restoreServers(payload.keychainItems.filter { $0.store == .servers })
        return AppMigrationSummary(serverNames: serverNames)
    }

    private func restoreDatabase(_ data: Data) throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("app-migration-\(UUID().uuidString).sqlite")
        defer { try? FileManager.default.removeItem(at: url) }
        try data.write(to: url)
        let source = try DatabaseQueue(path: url.path)
        try source.backup(to: Current.database())
        try source.close()
    }

    private func restoreDefaults(_ data: Data) throws {
        guard let incoming = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let defaults = UserDefaults(suiteName: AppConstants.AppGroupID) else {
            throw AppMigrationError.invalidPayload
        }
        var merged = defaults.persistentDomain(forName: AppConstants.AppGroupID) ?? [:]
        for (key, value) in incoming {
            merged[key] = value
        }
        defaults.setPersistentDomain(merged, forName: AppConstants.AppGroupID)
    }

    private func restoreKeychain(_ items: [AppMigrationPayload.KeychainItem]) {
        for item in items {
            try? Keychain(service: item.store.service).set(item.data, key: item.key)
        }
    }

    private func restoreServers(_ items: [AppMigrationPayload.KeychainItem]) throws -> [String] {
        let decoder = JSONDecoder()
        return try items.map { item in
            let info = try decoder.decode(ServerInfo.self, from: item.data)
            let server = Current.servers.add(identifier: .init(rawValue: item.key), serverInfo: info)
            Current.setCachedApi(HomeAssistantAPI(server: server), for: server.identifier)
            return server.info.name
        }
    }
}
