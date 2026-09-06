import Foundation

/// Reassembles the fragment frames the protocol uses for messages larger than a single Noise
/// transport message.
///
/// Only one fragmented message may be in flight per direction, so a single buffer is enough — and
/// any sequence that breaks that rule is a protocol error the caller must close the socket on.
struct SendspinFragmentReassembler {
    private static let lastFragmentFlag: UInt8 = 0b0000_0001
    private static let firstFragmentFlag: UInt8 = 0b0000_0010
    private static let reservedFlags: UInt8 = 0b1111_1100

    private var buffer = Data()
    private var originalType: UInt8?

    /// Feeds one decrypted frame in. Returns the complete message once its last fragment arrives,
    /// or `nil` while a fragmented message is still being assembled.
    mutating func accept(frame: Data) throws -> (id: UInt8, payload: Data)? {
        guard let id = frame.first else { throw SendspinProtocolError.malformedMessage }
        guard id == SendspinBinaryMessage.fragmentMessageId else {
            guard originalType == nil else { throw SendspinProtocolError.fragmentationViolation }
            return (id: id, payload: Data(frame.dropFirst()))
        }

        guard frame.count >= 2 else { throw SendspinProtocolError.malformedMessage }
        let flags = frame[frame.startIndex + 1]
        guard flags & Self.reservedFlags == 0 else { throw SendspinProtocolError.fragmentationViolation }
        let isFirst = flags & Self.firstFragmentFlag != 0
        let isLast = flags & Self.lastFragmentFlag != 0

        if isFirst {
            guard originalType == nil, frame.count >= 3 else { throw SendspinProtocolError.fragmentationViolation }
            let type = frame[frame.startIndex + 2]
            guard type != SendspinBinaryMessage.fragmentMessageId else {
                throw SendspinProtocolError.fragmentationViolation
            }
            originalType = type
            buffer = Data(frame.dropFirst(3))
        } else {
            guard originalType != nil else { throw SendspinProtocolError.fragmentationViolation }
            buffer.append(contentsOf: frame.dropFirst(2))
        }

        guard isLast, let type = originalType else { return nil }
        let payload = buffer
        buffer = Data()
        originalType = nil
        return (id: type, payload: payload)
    }

    mutating func reset() {
        buffer = Data()
        originalType = nil
    }
}
