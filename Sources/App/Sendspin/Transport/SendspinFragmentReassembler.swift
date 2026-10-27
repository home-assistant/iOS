import Foundation

/// Puts type `1` fragments back together. A malformed sequence is a protocol error the caller
/// answers by closing the connection.
struct SendspinFragmentReassembler {
    enum Failure: Error, Equatable {
        case missingFlags
        case reservedFlags
        case firstWhileInFlight
        case continuationWithoutFirst
        case missingOriginalType
        case nestedFragment
        case messageWhileInFlight
        case tooLarge
    }

    /// Bounds memory against a peer that never sends the last fragment.
    static let maximumMessageSize = 16 * 1024 * 1024

    private var buffer: Data?

    var isInFlight: Bool { buffer != nil }

    /// Feeds one decrypted plaintext. Returns the complete message (type byte first) when one is
    /// ready, or `nil` while a fragmented message is still arriving.
    mutating func receive(_ plaintext: Data) throws -> Data? {
        guard plaintext.first == SendspinBinaryType.fragment else {
            guard buffer == nil else {
                buffer = nil
                throw Failure.messageWhileInFlight
            }
            return plaintext
        }
        do {
            return try receiveFragment(Array(plaintext))
        } catch {
            buffer = nil
            throw error
        }
    }

    private mutating func receiveFragment(_ bytes: [UInt8]) throws -> Data? {
        guard bytes.count >= 2 else { throw Failure.missingFlags }
        let flags = bytes[1]
        guard flags & SendspinFragmentation.reservedFlags == 0 else { throw Failure.reservedFlags }

        let data: ArraySlice<UInt8>
        if flags & SendspinFragmentation.firstFlag != 0 {
            guard buffer == nil else { throw Failure.firstWhileInFlight }
            guard bytes.count >= 3 else { throw Failure.missingOriginalType }
            guard bytes[2] != SendspinBinaryType.fragment else { throw Failure.nestedFragment }
            buffer = Data([bytes[2]])
            data = bytes[3...]
        } else {
            guard buffer != nil else { throw Failure.continuationWithoutFirst }
            data = bytes[2...]
        }

        buffer?.append(contentsOf: data)
        guard (buffer?.count ?? 0) <= Self.maximumMessageSize else { throw Failure.tooLarge }
        guard flags & SendspinFragmentation.lastFlag != 0 else { return nil }
        defer { buffer = nil }
        return buffer
    }
}
