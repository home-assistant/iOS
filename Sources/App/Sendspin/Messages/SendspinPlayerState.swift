import Foundation

/// The `player` object of `client/state`: everything the server needs to schedule audio for this
/// device, plus which of its commands the device accepts.
struct SendspinPlayerState: Encodable, Equatable {
    /// Perceived-loudness volume, 0-100.
    let volume: Int
    let muted: Bool
    /// Delay beyond the audio port, clamped by the specification to 0-5000 ms.
    let outputDelayMs: Int
    /// Lead the player needs between a start trigger and the first playable chunk.
    let requiredLeadTimeMs: Int
    /// Ongoing buffer the player wants held to absorb jitter.
    let minBufferMs: Int
    let supportedCommands: [String]
    /// A preference overriding `supported_formats` priority, when the app has picked one.
    let format: SendspinAudioFormat?

    enum CodingKeys: String, CodingKey {
        case volume
        case muted
        case outputDelayMs = "output_delay_ms"
        case requiredLeadTimeMs = "required_lead_time_ms"
        case minBufferMs = "min_buffer_ms"
        case supportedCommands = "supported_commands"
        case format
    }
}
