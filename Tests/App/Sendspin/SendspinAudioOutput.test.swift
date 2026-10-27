import AVFoundation
import Foundation
@testable import HomeAssistant
import Testing

struct SendspinAudioOutputTests {
    private let format = SendspinStreamFormat(
        codec: "pcm",
        sampleRate: 48000,
        channels: 2,
        bitDepth: 16,
        codecHeader: nil
    )

    private func chunk() -> SendspinAudioChunk? {
        var message = Data([4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
        message.append(contentsOf: [0, 0x40, 0, 0xC0])
        return SendspinAudioChunk(message: message)
    }

    /// Without a stream there is nothing to decode into, so chunks are dropped.
    @Test func ignoresAudioOutsideAStream() throws {
        let output = SendspinAudioOutput()
        try output.enqueue(#require(chunk()))
        output.setVolume(50, muted: false)
        output.setOutputDelay(milliseconds: 20)
        output.update(mapping: SendspinClockMapping(lastUpdate: 0, offset: 10, drift: 0, useDrift: false))
        output.clear()
        output.stop()
        #expect(!output.isRunning)
    }

    /// The simulator may not have an audio device to start; when it does, the stream runs and stops.
    @Test func startsAndStopsAStream() throws {
        let output = SendspinAudioOutput()
        do {
            try output.start(format: format)
        } catch {
            return
        }
        // Starting again with the same rate and channels keeps the running engine.
        try output.start(format: SendspinStreamFormat(
            codec: "pcm",
            sampleRate: 48000,
            channels: 2,
            bitDepth: 24,
            codecHeader: nil
        ))
        try output.enqueue(#require(chunk()))
        output.setVolume(0, muted: true)
        output.clear()
        output.stop()
        #expect(!output.isRunning)
    }
}
