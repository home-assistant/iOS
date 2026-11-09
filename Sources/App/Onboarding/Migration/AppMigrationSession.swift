import CryptoKit
import Foundation

/// One transfer attempt: the new app mints the id and key, hands them to the previous app inside the
/// request URL, and only accepts a payload sealed with that key for that id.
struct AppMigrationSession: Equatable {
    let id: UUID
    let key: SymmetricKey

    static func make() -> AppMigrationSession {
        AppMigrationSession(id: UUID(), key: SymmetricKey(size: .bits256))
    }

    init(id: UUID, key: SymmetricKey) {
        self.id = id
        self.key = key
    }

    init?(id: UUID, keyString: String) {
        guard let data = Data(base64URLEncoded: keyString), data.count == 32 else { return nil }
        self.init(id: id, key: SymmetricKey(data: data))
    }

    var keyString: String {
        key.withUnsafeBytes { Data($0) }.base64URLEncodedString()
    }

    static func == (lhs: AppMigrationSession, rhs: AppMigrationSession) -> Bool {
        lhs.id == rhs.id && lhs.keyString == rhs.keyString
    }
}

private extension Data {
    init?(base64URLEncoded string: String) {
        var base64 = string.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while !base64.count.isMultiple(of: 4) {
            base64.append("=")
        }
        self.init(base64Encoded: base64)
    }

    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
