import Foundation

/// The `player` object of `server/command`. Commands the client did not advertise in
/// `supported_commands` are ignored rather than applied.
struct SendspinPlayerCommand: Decodable, Equatable {
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
