import Foundation
import KeychainAccess

// These protocols let ServerManager keep the core lifecycle logic independent from
// the concrete persistence backends used for the full record and the sanitized mirror.
protocol ServerManagerKeychain {
    func removeAll() throws
    func allKeys() -> [String]
    func getData(_ key: String) throws -> Data?
    func set(_ value: Data, key: String) throws
    func remove(_ key: String) throws
}

protocol ServerManagerMirrorStore {
    func removeAll()
    func allKeys() -> [String]
    func allServerInfo() -> [(String, ServerInfo)]
    func getServerInfo(_ key: String) -> ServerInfo?
    func set(_ serverInfo: ServerInfo, key: String)
    func remove(_ key: String)
}

extension Keychain: ServerManagerKeychain {
    public func set(_ value: Data, key: String) throws {
        try set(value, key: key, ignoringAttributeSynchronizable: true)
    }

    public func getData(_ key: String) throws -> Data? {
        try getData(key, ignoringAttributeSynchronizable: true)
    }

    public func remove(_ key: String) throws {
        try remove(key, ignoringAttributeSynchronizable: true)
    }
}

extension ServerManagerKeychain {
    func allServerInfo(decoder: JSONDecoder) -> [(String, ServerInfo)] {
        allKeys().compactMap { key in
            getServerInfo(key: key, decoder: decoder).map { (key, $0) }
        }
    }

    // Decode failures are logged and ignored so one bad Keychain entry does not
    // prevent the rest of the server list from loading.
    func getServerInfo(key: String, decoder: JSONDecoder) -> ServerInfo? {
        do {
            guard let data = try getData(key) else {
                return nil
            }

            return try decoder.decode(ServerInfo.self, from: data)
        } catch {
            Current.Log.error("failed to get server info for \(key): \(error)")
            return nil
        }
    }

    func set(serverInfo: ServerInfo, key: String, encoder: JSONEncoder) {
        do {
            try set(encoder.encode(serverInfo), key: key)
        } catch {
            Current.Log.error("failed to set server info for \(key): \(error)")
        }
    }

    func deleteServerInfo(key: String) {
        do {
            try remove(key)
        } catch {
            Current.Log.error("failed to delete server info for \(key): \(error.localizedDescription)")
        }
    }
}
