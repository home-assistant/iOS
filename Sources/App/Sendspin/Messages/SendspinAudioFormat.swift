import Foundation

/// An audio format as it appears in `supported_formats`, `client/state` and `stream/start`.
struct SendspinAudioFormat: Codable, Hashable {
    let codec: SendspinAudioCodec
    let channels: Int
    let sampleRate: Int
    /// Meaningful for `pcm` and `flac`; the specification says servers ignore it for `opus`.
    let bitDepth: Int

    enum CodingKeys: String, CodingKey {
        case codec
        case channels
        case sampleRate = "sample_rate"
        case bitDepth = "bit_depth"
    }

    /// Bytes one frame (one sample across every channel) occupies on the wire, for `pcm` streams.
    var bytesPerFrame: Int {
        channels * (bitDepth / 8)
    }
}
