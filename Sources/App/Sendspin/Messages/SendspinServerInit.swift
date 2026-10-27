import Foundation

/// `server/init`: the server's identity, the static key the handshake is pinned to.
struct SendspinServerInit: Codable, Equatable {
    let serverID: String
    let version: Int

    enum CodingKeys: String, CodingKey {
        case serverID = "server_id"
        case version
    }
}
