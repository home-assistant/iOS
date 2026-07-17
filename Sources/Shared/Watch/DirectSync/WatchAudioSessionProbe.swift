#if os(watchOS)
import AVFoundation
import Foundation

/// EXPERIMENT (not shipping as-is): holds a genuine playback `AVAudioSession` open by playing a
/// quiet looping tone, to test whether watchOS's audio-streaming exception (TN3135) unlocks
/// `URLSessionWebSocketTask` on real hardware. Real watches block low-level networking for
/// ordinary apps except while actively streaming audio; this proves whether that window is what
/// the direct websocket sync needs. It plays audible (low-volume) audio on purpose — the point is
/// to measure the exception, not to fake compliance.
final class WatchAudioSessionProbe {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var isRunning = false

    /// Activate the playback session and start looping the tone. Safe to call repeatedly.
    func start() {
        guard !isRunning else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            Current.Log.error("[AudioProbe] Failed to activate audio session: \(error)")
            return
        }

        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        guard let buffer = Self.makeToneBuffer(format: format) else {
            Current.Log.error("[AudioProbe] Failed to build tone buffer")
            return
        }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        // Low but non-zero: genuinely playing audio, quiet enough not to be obnoxious in testing.
        engine.mainMixerNode.outputVolume = 0.05
        do {
            try engine.start()
        } catch {
            Current.Log.error("[AudioProbe] Failed to start audio engine: \(error)")
            return
        }
        player.scheduleBuffer(buffer, at: nil, options: [.loops])
        player.play()
        isRunning = true
        Current.Log.info("[AudioProbe] Audio session active — low-level networking window should be open")
    }

    func stop() {
        guard isRunning else { return }
        player.stop()
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        isRunning = false
        Current.Log.info("[AudioProbe] Audio session deactivated")
    }

    /// One second of a quiet 440 Hz sine, looped by the player node.
    private static func makeToneBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(format.sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channel = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount
        let frequency = 440.0
        let amplitude: Float = 0.2
        for frame in 0 ..< Int(frameCount) {
            let value = sin(2.0 * .pi * frequency * Double(frame) / format.sampleRate)
            channel[frame] = Float(value) * amplitude
        }
        return buffer
    }
}
#endif
