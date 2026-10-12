import Foundation

/// `client/init`: the first, cleartext message, naming this device's identity and cipher suite.
struct SendspinClientInit: Codable, Equatable {
    static let protocolVersion = 1
    static let suite = "25519_ChaChaPoly_SHA256"

    let clientID: String
    let version: Int
    let suite: String

    init(clientID: String) {
        self.clientID = clientID
        self.version = Self.protocolVersion
        self.suite = Self.suite
    }

    enum CodingKeys: String, CodingKey {
        case clientID = "client_id"
        case version
        case suite
    }
}
