import CryptoKit
import Foundation

/// The device's long-lived Curve25519 identity. The base64url form of its public key is the
/// `client_id` servers know this device by, so replacing the key makes the phone a new player.
struct SendspinIdentity {
    let privateKey: Curve25519.KeyAgreement.PrivateKey

    var privateKeyBytes: Data { privateKey.rawRepresentation }
    var publicKeyBytes: Data { privateKey.publicKey.rawRepresentation }
    var clientID: String { SendspinBase64URL.encode(publicKeyBytes) }

    init(privateKey: Curve25519.KeyAgreement.PrivateKey) {
        self.privateKey = privateKey
    }

    init?(privateKeyBytes: Data) {
        guard let key = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: privateKeyBytes) else {
            return nil
        }
        self.privateKey = key
    }

    static func generate() -> SendspinIdentity {
        SendspinIdentity(privateKey: Curve25519.KeyAgreement.PrivateKey())
    }
}
