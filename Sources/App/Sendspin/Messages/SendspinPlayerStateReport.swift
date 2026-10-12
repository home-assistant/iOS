import Foundation

/// The `player` object of `client/state`.
struct SendspinPlayerStateReport: Codable, Equatable {
    static let supportedCommands = ["volume", "mute", "set_output_delay"]

    let volume: Int
    let muted: Bool
    let outputDelayMs: Int
    let requiredLeadTimeMs: Int
    let minBufferMs: Int
    let supportedCommands: [String]

    enum CodingKeys: String, CodingKey {
        case volume
        case muted
        case outputDelayMs = "output_delay_ms"
        case requiredLeadTimeMs = "required_lead_time_ms"
        case minBufferMs = "min_buffer_ms"
        case supportedCommands = "supported_commands"
    }
}
