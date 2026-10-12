import Foundation

/// `server/command`.
struct SendspinServerCommand: Codable, Equatable {
    let player: SendspinPlayerCommand?
}
