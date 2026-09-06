import CryptoKit
import Foundation

/// The device's long-lived Curve25519 identity. The base64url form of its public key is the
/// `client_id` servers know this device by, so rotating the secret creates a new device identity.
struct SendspinIdentity {
    let privateKey: Curve25519.KeyAgreement.PrivateKey

    var secretKeyBytes: Data { privateKey.rawRepresentation }
    var publicKeyBytes: Data { privateKey.publicKey.rawRepresentation }
    var clientId: String { SendspinBase64URL.encode(publicKeyBytes) }

    init(privateKey: Curve25519.KeyAgreement.PrivateKey) {
        self.privateKey = privateKey
    }

    init?(secretKeyBytes: Data) {
        guard let key = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: secretKeyBytes) else {
            return nil
        }
        privateKey = key
    }

    static func generate() -> SendspinIdentity {
        SendspinIdentity(privateKey: Curve25519.KeyAgreement.PrivateKey())
    }
}
