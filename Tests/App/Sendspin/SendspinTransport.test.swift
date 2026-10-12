import Foundation
@testable import HomeAssistant
import Testing

struct SendspinTransportTests {
    @Test func smallMessagesAreNotFragmented() throws {
        let message = Data([0]) + Data("{}".utf8)
        #expect(SendspinFragmentation.plaintexts(for: message) == [message])
        var reassembler = SendspinFragmentReassembler()
        #expecttry (reassembler.receive(message) == message)
    }

    @Test func largeMessagesRoundTripThroughFragments() throws {
        var message = Data([8])
        message.append(Data((0 ..< 150_000).map { UInt8($0 % 251) }))
        let fragments = SendspinFragmentation.plaintexts(for: message)
        #expect(fragments.count == 3)
        #expect(fragments.allSatisfy { $0.count <= SendspinFragmentation.maximumPlaintext })
        #expect(fragments.first?[1] == SendspinFragmentation.firstFlag)
        #expect(fragments.last?[1] == SendspinFragmentation.lastFlag)

        var reassembler = SendspinFragmentReassembler()
        #expecttry (reassembler.receive(fragments[0]) == nil)
        #expect(reassembler.isInFlight)
        #expecttry (reassembler.receive(fragments[1]) == nil)
        #expecttry (reassembler.receive(fragments[2]) == message)
        #expect(!reassembler.isInFlight)
    }

    @Test(arguments: [
        ([Data([1])], SendspinFragmentReassembler.Failure.missingFlags),
        ([Data([1, 0x80, 4])], .reservedFlags),
        ([Data([1, 0x02, 4]), Data([1, 0x02, 4])], .firstWhileInFlight),
        ([Data([1, 0x01, 4])], .continuationWithoutFirst),
        ([Data([1, 0x02])], .missingOriginalType),
        ([Data([1, 0x02, 1])], .nestedFragment),
        ([Data([1, 0x02, 4]), Data([0])], .messageWhileInFlight),
    ])
    func malformedSequencesAreProtocolErrors(frames: [Data], failure: SendspinFragmentReassembler.Failure) {
        var reassembler = SendspinFragmentReassembler()
        #expect(throws: failure) {
            for frame in frames {
                _ = try reassembler.receive(frame)
            }
        }
        #expect(!reassembler.isInFlight)
    }

    @Test func parsesAudioChunks() throws {
        var message = Data([4, 0, 0, 0, 0, 0, 0x0F, 0x42, 0x40, 0, 0, 0x27, 0x10])
        message.append(contentsOf: [1, 2, 3, 4])
        let chunk = try #require(SendspinAudioChunk(message: message))
        #expect(chunk.timestamp == 1_000_000)
        #expect(chunk.sendAhead == 10000)
        #expect(chunk.payload == Data([1, 2, 3, 4]))
        #expect(SendspinAudioChunk(message: Data([4, 0, 0])) == nil)
        #expect(SendspinAudioChunk(message: Data([8] + Array(repeating: 0, count: 12))) == nil)
    }
}
