import Foundation

/// What this device tells a server about itself, and the player settings it starts a session with.
struct SendspinPlayerConfiguration {
    let name: String
    /// Priority order; the server picks the first entry it can produce for the current track.
    let supportedFormats: [SendspinAudioFormat]
    /// Hard byte cap on the compressed audio a server may leave queued here.
    let bufferCapacity: Int
    /// Lead between a start trigger and the first chunk that can play in full.
    let requiredLeadTimeMs: Int
    /// Buffer held during playback to absorb Wi-Fi jitter.
    let minBufferMs: Int
    let unpairedAccessEnabled: Bool
    let outputDelayMilliseconds: Int
    let volume: Int
    let muted: Bool

    /// Only PCM is offered: decoding FLAC or Opus would mean shipping a decoder, and a server is
    /// required to be able to produce every codec, so a LAN player loses nothing by asking for the
    /// one that needs none.
    static let defaultFormats: [SendspinAudioFormat] = [
        SendspinAudioFormat(codec: .pcm, channels: 2, sampleRate: 48_000, bitDepth: 16),
        SendspinAudioFormat(codec: .pcm, channels: 2, sampleRate: 44_100, bitDepth: 16),
    ]

    static func current(name: String) -> SendspinPlayerConfiguration {
        SendspinPlayerConfiguration(
            name: name,
            supportedFormats: defaultFormats,
            // Two seconds of 48 kHz stereo PCM: enough for the server to ride out a Wi-Fi stall.
            bufferCapacity: 384_000,
            requiredLeadTimeMs: 300,
            minBufferMs: 700,
            unpairedAccessEnabled: SendspinPreferences.unpairedAccessEnabled,
            outputDelayMilliseconds: SendspinPreferences.outputDelayMilliseconds,
            volume: SendspinPreferences.volume,
            muted: SendspinPreferences.isMuted
        )
    }
}
