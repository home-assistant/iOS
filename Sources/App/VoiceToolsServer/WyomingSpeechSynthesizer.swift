import AVFoundation
import Foundation
import Shared

/// Renders text to raw PCM with `AVSpeechSynthesizer`, without playing it.
///
/// `write(_:toBufferCallback:)` is what makes serving text-to-speech possible at all: it hands the
/// rendered buffers back instead of routing them to the speaker, so answering Home Assistant never
/// interrupts what the device is playing and needs no audio session.
///
/// An actor rather than a `@MainActor` type: resolving a voice blocks its caller on the
/// TextToSpeech daemon for over a hundred milliseconds, which does not belong on the main thread,
/// and the connection calling this is already off it.
actor WyomingSpeechSynthesizer {
    struct Output {
        let format: WyomingAudioFormat
        /// Little-endian 16-bit PCM, ready to go out as `audio-chunk` payloads.
        let audio: Data
    }

    /// A render that never calls back would hold the connection open forever: cancelling the task
    /// awaiting a continuation does not resume it.
    private static let renderTimeout: TimeInterval = 30

    private let synthesizer = AVSpeechSynthesizer()

    /// Collects the buffers `write` produces and owns the continuation waiting on them.
    ///
    /// The buffer callback runs on the synthesiser's own queue while the timeout fires on another,
    /// so the continuation is handed out under a lock and only ever once; the audio itself is only
    /// touched by the serial buffer callback.
    private final class Render: @unchecked Sendable {
        var audio = Data()
        var sampleRate = 0

        private var continuation: CheckedContinuation<Render, Error>?
        private let lock = NSLock()

        init(continuation: CheckedContinuation<Render, Error>) {
            self.continuation = continuation
        }

        func finish(with result: Result<Render, Error>) {
            lock.lock()
            let pending = continuation
            continuation = nil
            lock.unlock()
            pending?.resume(with: result)
        }
    }

    func synthesize(text: String, voiceIdentifier: String?, language: String?) async throws -> Output {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw WyomingProtocolError.synthesisFailed }

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = voice(identifier: voiceIdentifier, language: language)

        let render = try await withCheckedThrowingContinuation { continuation in
            let render = Render(continuation: continuation)
            let timeout = DispatchWorkItem { render.finish(with: .failure(WyomingProtocolError.timedOut)) }
            DispatchQueue.global(qos: .userInitiated).asyncAfter(
                deadline: .now() + Self.renderTimeout,
                execute: timeout
            )

            synthesizer.write(utterance) { buffer in
                // `write` signals the end of the utterance with an empty buffer. That is the only
                // completion it offers here: the delegate's `didFinish` reports spoken playback.
                guard let pcmBuffer = buffer as? AVAudioPCMBuffer, pcmBuffer.frameLength > 0 else {
                    timeout.cancel()
                    render.finish(with: .success(render))
                    return
                }
                render.sampleRate = Int(pcmBuffer.format.sampleRate)
                render.audio.append(Self.int16Samples(from: pcmBuffer))
            }
        }

        guard !render.audio.isEmpty, render.sampleRate > 0 else {
            throw WyomingProtocolError.synthesisFailed
        }
        return Output(
            format: WyomingAudioFormat(
                rate: render.sampleRate,
                width: WyomingAudioFormat.supportedWidth,
                channels: 1
            ),
            audio: render.audio
        )
    }

    /// Voices are looked up by the identifier this server advertised in its `info`. A language is
    /// the fallback for a client that names one without picking a voice; `nil` lets the system choose.
    private func voice(identifier: String?, language: String?) -> AVSpeechSynthesisVoice? {
        if let identifier, let voice = AVSpeechSynthesisVoice(identifier: identifier) {
            return voice
        }
        if let language, let voice = AVSpeechSynthesisVoice(language: language) {
            return voice
        }
        return nil
    }

    /// Flattens a rendered buffer to little-endian 16-bit mono, the only format Wyoming carries.
    ///
    /// The synthesiser produces integer buffers for the built-in voices and float ones for some
    /// downloaded and personal voices, so both are handled rather than one being assumed away.
    private static func int16Samples(from buffer: AVAudioPCMBuffer) -> Data {
        let frameLength = Int(buffer.frameLength)
        // Interleaved buffers pack the channels together, so a stereo voice is thinned to its first
        // channel rather than read as twice as many mono frames.
        let stride = buffer.format.isInterleaved ? Int(buffer.format.channelCount) : 1
        var samples = [Int16](repeating: 0, count: frameLength)

        if let int16Data = buffer.int16ChannelData {
            let source = int16Data[0]
            for frame in 0 ..< frameLength {
                samples[frame] = source[frame * stride]
            }
        } else if let floatData = buffer.floatChannelData {
            let source = floatData[0]
            for frame in 0 ..< frameLength {
                let value = max(-1, min(1, source[frame * stride]))
                samples[frame] = Int16(value * Float(Int16.max))
            }
        } else {
            return Data()
        }

        return samples.withUnsafeBufferPointer { Data(buffer: $0) }
    }
}
