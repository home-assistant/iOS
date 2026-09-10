import Foundation
import Security

/// The real storage: the Keychain group the app and the extension share.
///
/// `kSecAttrAccessGroup` is deliberately not set. Both the app and the extension declare exactly one
/// `keychain-access-groups` entry and it is the same one, so the default group already is the shared
/// group and no new entitlement is needed.
public struct RemoteMediaKeychainStorage: RemoteMediaSecureStorage {
    public enum StorageError: Error, Equatable {
        case unhandled(status: OSStatus)
    }

    public init() {}

    public func data() -> Data? {
        var query = Self.baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }

    public func save(_ data: Data) throws {
        // After first unlock, this device only: Lock Screen and Control Center send commands while
        // the phone is locked, and a webhook secret has no business syncing anywhere.
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        let status = SecItemUpdate(Self.baseQuery as CFDictionary, attributes as CFDictionary)
        switch status {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var query = Self.baseQuery
            query.merge(attributes) { _, new in new }
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw StorageError.unhandled(status: addStatus) }
        default:
            throw StorageError.unhandled(status: status)
        }
    }

    public func clear() {
        let status = SecItemDelete(Self.baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            RemoteMediaLog.logger.error("transport context delete failed status=\(status, privacy: .public)")
            return
        }
    }

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "io.home-assistant.remote-media.transport",
            kSecAttrAccount as String: "context",
        ]
    }
}
