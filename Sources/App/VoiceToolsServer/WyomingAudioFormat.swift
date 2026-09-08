import AVFoundation
import Foundation

/// The PCM format a Wyoming `audio-start` or `audio-chunk` event describes.
///
/// Wyoming carries raw little-endian PCM and repeats the format on every audio event, so one value
/// describes both what a client streams in for transcription and what this server announces for the
/// speech it synthesises.
struct WyomingAudioFormat: Codable, Equatable {
    /// Samples per second. Home Assistant records at 16 kHz.
    let rate: Int
    /// Bytes per sample. Wyoming only ever uses 16-bit audio.
    let width: Int
    let channels: Int

    /// Only 16-bit PCM is accepted; `width` is a byte count, so anything but 2 is rejected rather
    /// than guessed at, which would hand the recogniser noise instead of speech.
    static let supportedWidth = 2

    var bytesPerFrame: Int { width * channels }

    /// The same audio as an interleaved integer PCM format, or `nil` when it is not 16-bit audio.
    var pcmFormat: AVAudioFormat? {
        guard width == Self.supportedWidth, rate > 0, channels > 0 else { return nil }
        return AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: Double(rate),
            channels: AVAudioChannelCount(channels),
            interleaved: true
        )
    }
}
