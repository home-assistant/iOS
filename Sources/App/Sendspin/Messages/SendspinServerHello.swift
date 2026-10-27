import Foundation

/// `server/hello`, the first encrypted message.
struct SendspinServerHello: Codable, Equatable {
    let name: String
    let languages: [String]?
}
