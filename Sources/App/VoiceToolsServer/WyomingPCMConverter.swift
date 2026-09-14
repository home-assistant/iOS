import AVFoundation
import Foundation
import Shared

/// Turns the little-endian 16-bit PCM a Wyoming client streams into the float buffers the speech
/// recogniser is fed.
///
/// Split out of `WyomingSpeechRecognitionSession` because it is the half that stands on its own:
/// converting audio needs no recogniser, no speech authorisation and no permission prompt, which is
/// also what makes the frame arithmetic below testable.
struct WyomingPCMConverter {
    /// The float format an `AVAudioEngine` tap produces, at the client's own sample rate: no
    /// resampling, only the integer-to-float and channel change, which `AVAudioConverter` does in
    /// one pass without the pull-style input block.
    let outputFormat: AVAudioFormat

    private let sourceFormat: AVAudioFormat
    private let converter: AVAudioConverter
    private let bytesPerFrame: Int

    /// Bytes left over from a chunk that did not end on a frame boundary. Home Assistant sends whole
    /// frames, but nothing in the protocol promises it, and half a frame carried into the next chunk
    /// would shift every following sample by a byte and turn speech into noise.
    private var remainder = Data()

    init(format: WyomingAudioFormat) throws {
        guard let sourceFormat = format.pcmFormat,
              let outputFormat = AVAudioFormat(
                  standardFormatWithSampleRate: sourceFormat.sampleRate,
                  channels: 1
              ),
              let converter = AVAudioConverter(from: sourceFormat, to: outputFormat) else {
            throw WyomingProtocolError.unsupportedAudioFormat(format)
        }

        self.sourceFormat = sourceFormat
        self.outputFormat = outputFormat
        self.converter = converter
        self.bytesPerFrame = format.bytesPerFrame
    }

    /// Converts every whole frame `audio` completes, keeping any partial frame for the next call.
    /// Answers `nil` when there is not yet a whole frame to convert.
    mutating func convert(_ audio: Data) -> AVAudioPCMBuffer? {
        remainder.append(audio)
        let frameCount = remainder.count / bytesPerFrame
        guard frameCount > 0 else { return nil }

        let consumed = frameCount * bytesPerFrame
        let frames = Data(remainder.prefix(consumed))
        remainder = Data(remainder.dropFirst(consumed))

        return makeBuffer(from: frames, frameCount: AVAudioFrameCount(frameCount))
    }

    private func makeBuffer(from audio: Data, frameCount: AVAudioFrameCount) -> AVAudioPCMBuffer? {
        guard let source = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: frameCount),
              let target = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: frameCount),
              let channelData = source.int16ChannelData else {
            return nil
        }
        source.frameLength = frameCount
        // Copied through a raw pointer rather than rebound to `Int16`: `Data`'s buffer carries no
        // alignment promise, and the samples are little-endian on every platform this ships to.
        audio.copyBytes(to: UnsafeMutableRawBufferPointer(start: channelData[0], count: audio.count))

        do {
            try converter.convert(to: target, from: source)
        } catch {
            Current.Log.error("Wyoming: failed to convert incoming audio: \(error)")
            return nil
        }
        return target
    }
}
