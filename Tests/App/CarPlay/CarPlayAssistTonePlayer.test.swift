import AVFoundation
import Foundation
@testable import HomeAssistant
import Testing

/// The tones are synthesized rather than bundled: these check the generated WAV data, its cache,
/// and that delegate callbacks for a player the tone player no longer owns are ignored. Playback
/// itself goes to the audio output and is left to the device.
struct CarPlayAssistTonePlayerTests {
    private func uint32(_ data: Data, at offset: Int) -> UInt32 {
        data.subdata(in: offset ..< offset + 4).withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
    }

    @Test(arguments: [CarPlayAssistTonePlayer.Tone.startRecording, .processing, .error])
    func everyToneIsAPlayableMonoWAV(tone: CarPlayAssistTonePlayer.Tone) throws {
        let data = CarPlayAssistTonePlayer().toneData(for: tone)

        #expect(String(decoding: data.prefix(4), as: UTF8.self) == "RIFF")
        #expect(String(decoding: data.subdata(in: 8 ..< 12), as: UTF8.self) == "WAVE")
        #expect(String(decoding: data.subdata(in: 36 ..< 40), as: UTF8.self) == "data")
        #expect(uint32(data, at: 4) == UInt32(data.count - 8))
        #expect(uint32(data, at: 24) == 44100)
        let duration = CarPlayAssistTonePlayer.segments(for: tone).map(\.duration).reduce(0, +)
        #expect(uint32(data, at: 40) == UInt32(data.count - 44))

        let player = try AVAudioPlayer(data: data, fileTypeHint: AVFileType.wav.rawValue)
        #expect(abs(player.duration - duration) < 0.01)
    }

    @Test func theTwoChimesMirrorEachOther() {
        let start = CarPlayAssistTonePlayer.segments(for: .startRecording).map(\.frequency)
        let processing = CarPlayAssistTonePlayer.segments(for: .processing).map(\.frequency)

        #expect(start == processing.reversed())
        #expect(CarPlayAssistTonePlayer.segments(for: .error).contains { $0.frequency == 0 })
    }

    /// A silent segment is all zero samples.
    @Test func aSilentSegmentIsSilence() {
        let data = CarPlayAssistTonePlayer.makeWAVData(segments: [.init(frequency: 0, duration: 0.01)])

        #expect(data.count == 44 + 441 * 2)
        #expect(data.dropFirst(44).allSatisfy { $0 == 0 })
    }

    @Test func toneDataIsCachedPerTone() {
        let sut = CarPlayAssistTonePlayer()

        #expect(sut.toneData(for: .error) == sut.toneData(for: .error))
        #expect(sut.toneData(for: .error) != sut.toneData(for: .processing))
    }

    /// Callbacks from a player that is not (or no longer) the current one never fire a completion.
    @Test func callbacksFromAForeignPlayerAreIgnored() throws {
        let sut = CarPlayAssistTonePlayer()
        let foreign = try AVAudioPlayer(data: sut.toneData(for: .processing), fileTypeHint: AVFileType.wav.rawValue)

        sut.audioPlayerDidFinishPlaying(foreign, successfully: true)
        sut.audioPlayerDecodeErrorDidOccur(foreign, error: nil)
        sut.audioPlayerDecodeErrorDidOccur(foreign, error: NSError(domain: "test", code: 1))
        sut.stop()
        // The delegate hops onto the player's queue; a stop() after it drains that queue.
        sut.stop()
    }
}
