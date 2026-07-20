import AVFoundation
import Foundation
import Shared

/// Plays the CarPlay Assist feedback tones through the shared audio session instead of the
/// system sound server, so they behave like media playback: routed with the rest of the
/// Assist audio and not silenced by the iPhone ring/silent switch.
final class CarPlayAssistTonePlayer: NSObject {
    enum Tone {
        /// Rising two-note chime, replaces the system "begin record" sound.
        case startRecording
        /// Falling two-note chime, replaces the Siri "stop/success" sound.
        case processing
        /// Low double buzz, replaces the system "unexpected error" sound.
        case error
    }

    private struct Segment {
        /// Frequency in hertz, `0` produces silence for `duration`.
        let frequency: Double
        let duration: TimeInterval
    }

    private static let sampleRate: Double = 44100
    private static let amplitude: Double = 0.4
    private static let fadeDuration: TimeInterval = 0.008

    /// Serial queue protecting `player` and `completion`; calls arrive from CarPlay template
    /// callbacks, HAKit and URLSession threads, and AVAudioPlayer delegate callbacks.
    private let queue = DispatchQueue(label: "io.home-assistant.carplay-assist-tone-player")
    private var player: AVAudioPlayer?
    private var completion: (() -> Void)?
    private var cachedToneData: [Tone: Data] = [:]

    /// Plays `tone` through the currently configured audio session. `completion` runs once
    /// playback finishes or fails to start; it does not run if the tone is interrupted by
    /// `stop()` or another `play(_:completion:)` call. `completion` must not call back into
    /// this player.
    func play(_ tone: Tone, completion: (() -> Void)? = nil) {
        queue.sync {
            self.completion = nil
            player?.stop()
            player = nil

            do {
                let player = try AVAudioPlayer(data: toneData(for: tone), fileTypeHint: AVFileType.wav.rawValue)
                player.delegate = self
                player.prepareToPlay()
                self.player = player
                self.completion = completion
                if !player.play() {
                    Current.Log.error("CarPlay Assist tone player failed to start playback")
                    finishPlayback()
                }
            } catch {
                Current.Log.error("CarPlay Assist tone player failed to create player: \(error.localizedDescription)")
                completion?()
            }
        }
    }

    /// Synchronously stops any playing tone without firing its pending completion, so the
    /// audio session can be deactivated right afterwards.
    func stop() {
        queue.sync {
            completion = nil
            player?.stop()
            player = nil
        }
    }

    private func finishPlayback() {
        player = nil
        let pendingCompletion = completion
        completion = nil
        pendingCompletion?()
    }

    private func toneData(for tone: Tone) -> Data {
        if let cached = cachedToneData[tone] {
            return cached
        }
        let data = Self.makeWAVData(segments: Self.segments(for: tone))
        cachedToneData[tone] = data
        return data
    }

    private static func segments(for tone: Tone) -> [Segment] {
        switch tone {
        case .startRecording:
            [
                Segment(frequency: 659.26, duration: 0.09),
                Segment(frequency: 880, duration: 0.13),
            ]
        case .processing:
            [
                Segment(frequency: 880, duration: 0.09),
                Segment(frequency: 659.26, duration: 0.13),
            ]
        case .error:
            [
                Segment(frequency: 392, duration: 0.12),
                Segment(frequency: 0, duration: 0.04),
                Segment(frequency: 311.13, duration: 0.18),
            ]
        }
    }

    private static func makeWAVData(segments: [Segment]) -> Data {
        var samples = [Int16]()
        for segment in segments {
            let sampleCount = Int(segment.duration * sampleRate)
            guard segment.frequency > 0 else {
                samples.append(contentsOf: [Int16](repeating: 0, count: sampleCount))
                continue
            }
            // Short fades avoid audible clicks at segment boundaries.
            let fadeSampleCount = min(Int(fadeDuration * sampleRate), sampleCount / 2)
            for index in 0 ..< sampleCount {
                var value = sin(2 * .pi * segment.frequency * Double(index) / sampleRate) * amplitude
                if fadeSampleCount > 0 {
                    if index < fadeSampleCount {
                        value *= Double(index) / Double(fadeSampleCount)
                    } else if index >= sampleCount - fadeSampleCount {
                        value *= Double(sampleCount - 1 - index) / Double(fadeSampleCount)
                    }
                }
                samples.append(Int16(value * Double(Int16.max - 1)))
            }
        }

        let dataChunkSize = UInt32(samples.count * MemoryLayout<Int16>.size)
        var data = Data()
        data.append(contentsOf: Array("RIFF".utf8))
        appendLittleEndian(UInt32(36) + dataChunkSize, to: &data)
        data.append(contentsOf: Array("WAVE".utf8))
        data.append(contentsOf: Array("fmt ".utf8))
        appendLittleEndian(UInt32(16), to: &data)
        appendLittleEndian(UInt16(1), to: &data) // PCM
        appendLittleEndian(UInt16(1), to: &data) // mono
        appendLittleEndian(UInt32(sampleRate), to: &data)
        appendLittleEndian(UInt32(sampleRate) * 2, to: &data) // byte rate
        appendLittleEndian(UInt16(2), to: &data) // block align
        appendLittleEndian(UInt16(16), to: &data) // bits per sample
        data.append(contentsOf: Array("data".utf8))
        appendLittleEndian(dataChunkSize, to: &data)
        for sample in samples {
            appendLittleEndian(UInt16(bitPattern: sample), to: &data)
        }
        return data
    }

    private static func appendLittleEndian(_ value: some FixedWidthInteger, to data: inout Data) {
        withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }
}

// MARK: - AVAudioPlayerDelegate

extension CarPlayAssistTonePlayer: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        queue.async { [weak self] in
            guard let self, self.player === player else { return }
            finishPlayback()
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Current.Log.error("CarPlay Assist tone player decode error: \(error?.localizedDescription ?? "unknown error")")
        queue.async { [weak self] in
            guard let self, self.player === player else { return }
            finishPlayback()
        }
    }
}
