import Foundation

/// `server/error`, sent in place of `server/init` when the server refuses `client/init`.
struct SendspinServerError: Codable, Equatable {
    let reason: String
}
