import Foundation

/// The `player` object of `server/command`.
struct SendspinPlayerCommand: Codable, Equatable {
    let command: String
    let volume: Int?
    let mute: Bool?
    let outputDelayMs: Int?

    enum CodingKeys: String, CodingKey {
        case command
        case volume
        case mute
        case outputDelayMs = "output_delay_ms"
    }
}
