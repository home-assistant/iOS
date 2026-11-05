import CryptoKit
import Foundation

/// AES-GCM around the payload so the pasteboard never holds readable credentials.
enum AppMigrationCrypto {
    static func seal(_ data: Data, key: SymmetricKey) throws -> Data {
        guard let combined = try AES.GCM.seal(data, using: key).combined else {
            throw AppMigrationError.invalidPayload
        }
        return combined
    }

    static func open(_ data: Data, key: SymmetricKey) throws -> Data {
        do {
            return try AES.GCM.open(AES.GCM.SealedBox(combined: data), using: key)
        } catch {
            throw AppMigrationError.invalidPayload
        }
    }
}
