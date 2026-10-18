import Foundation
@testable import HomeAssistant
import Testing

struct WAVDataChunkTests {
    private func chunk(_ id: String, _ payload: [UInt8]) -> [UInt8] {
        let size = UInt32(payload.count)
        return Array(id.utf8) + [
            UInt8(size & 0xFF), UInt8(size >> 8 & 0xFF), UInt8(size >> 16 & 0xFF), UInt8(size >> 24),
        ] + payload + (payload.count % 2 == 1 ? [0] : [])
    }

    private func wav(chunks: [[UInt8]]) -> Data {
        let body = Array("WAVE".utf8) + chunks.flatMap { $0 }
        let size = UInt32(body.count)
        return Data(Array("RIFF".utf8) + [
            UInt8(size & 0xFF), UInt8(size >> 8 & 0xFF), UInt8(size >> 16 & 0xFF), UInt8(size >> 24),
        ] + body)
    }

    @Test func returnsTheSamplesOfTheDataChunk() {
        let samples: [UInt8] = [1, 2, 3, 4, 5, 6]
        let file = wav(chunks: [chunk("fmt ", Array(repeating: 0, count: 16)), chunk("data", samples)])

        #expect(WAVDataChunk.pcm(in: file) == Data(samples))
    }

    @Test func skipsPaddingChunksBeforeTheData() {
        let samples: [UInt8] = [9, 8, 7, 6]
        let file = wav(chunks: [
            chunk("fmt ", Array(repeating: 0, count: 16)),
            chunk("FLLR", Array(repeating: 0, count: 4045)),
            chunk("data", samples),
        ])

        #expect(WAVDataChunk.pcm(in: file) == Data(samples))
    }

    @Test func clampsADataChunkThatClaimsMoreThanTheFileHolds() {
        var file = wav(chunks: [chunk("data", [1, 2, 3, 4])])
        file[file.startIndex + 16] = 0xFF

        #expect(WAVDataChunk.pcm(in: file) == Data([1, 2, 3, 4]))
    }

    @Test func passesRawPCMThroughUntouched() {
        let raw = Data([0x10, 0x20, 0x30, 0x40])

        #expect(WAVDataChunk.pcm(in: raw) == raw)
    }

    @Test func answersNothingForAWaveFileWithoutSamples() {
        let file = wav(chunks: [chunk("fmt ", Array(repeating: 0, count: 16))])

        #expect(WAVDataChunk.pcm(in: file).isEmpty)
    }
}
