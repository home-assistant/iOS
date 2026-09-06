import Foundation
@testable import HomeAssistant
import Testing

struct SendspinFragmentReassemblerTests {
    private let fragmentId: UInt8 = 1
    private let firstFlag: UInt8 = 0b10
    private let lastFlag: UInt8 = 0b01

    @Test func passesNonFragmentedFramesStraightThrough() throws {
        var reassembler = SendspinFragmentReassembler()
        let result = try #require(reassembler.accept(frame: Data([0, 0x7B, 0x7D])))
        #expect(result.id == 0)
        #expect(result.payload == Data([0x7B, 0x7D]))
    }

    @Test func reassemblesThreeFragmentsIntoOneMessage() throws {
        var reassembler = SendspinFragmentReassembler()
        #expect(try reassembler.accept(frame: Data([fragmentId, firstFlag, 4, 0xAA])) == nil)
        #expect(try reassembler.accept(frame: Data([fragmentId, 0, 0xBB])) == nil)
        let result = try #require(reassembler.accept(frame: Data([fragmentId, lastFlag, 0xCC])))
        #expect(result.id == 4)
        #expect(result.payload == Data([0xAA, 0xBB, 0xCC]))
    }

    /// Only one fragmented message may be in flight per direction; anything else is a protocol
    /// error the caller has to close the connection on.
    @Test func rejectsASecondFragmentedMessageWhileOneIsInFlight() throws {
        var reassembler = SendspinFragmentReassembler()
        _ = try reassembler.accept(frame: Data([fragmentId, firstFlag, 4, 0xAA]))
        #expect(throws: SendspinProtocolError.self) {
            _ = try reassembler.accept(frame: Data([fragmentId, firstFlag, 4, 0xBB]))
        }
    }

    @Test func rejectsAContinuationWithNothingInFlight() {
        var reassembler = SendspinFragmentReassembler()
        #expect(throws: SendspinProtocolError.self) {
            _ = try reassembler.accept(frame: Data([fragmentId, 0, 0xAA]))
        }
    }

    @Test func rejectsAPlainFrameWhileAMessageIsInFlight() throws {
        var reassembler = SendspinFragmentReassembler()
        _ = try reassembler.accept(frame: Data([fragmentId, firstFlag, 4, 0xAA]))
        #expect(throws: SendspinProtocolError.self) {
            _ = try reassembler.accept(frame: Data([0, 0x7B]))
        }
    }

    @Test func rejectsReservedFlagBits() {
        var reassembler = SendspinFragmentReassembler()
        #expect(throws: SendspinProtocolError.self) {
            _ = try reassembler.accept(frame: Data([fragmentId, 0b1000_0010, 4, 0xAA]))
        }
    }

    @Test func rejectsAFragmentOfAFragment() {
        var reassembler = SendspinFragmentReassembler()
        #expect(throws: SendspinProtocolError.self) {
            _ = try reassembler.accept(frame: Data([fragmentId, firstFlag, 1, 0xAA]))
        }
    }
}
