import Foundation

/// A binary type `4` message: timestamped audio for the player role.
struct SendspinAudioChunk: Equatable {
    /// Server time, in microseconds, at which the first sample should leave the speaker.
    let timestamp: Int64
    /// Microseconds the server had in hand when it sent the chunk; only ever used to measure
    /// arrival delay, never for scheduling.
    let sendAhead: UInt32
    let payload: Data

    static let headerLength = 13

    /// - Parameter message: The complete decrypted message, type byte included.
    init?(message: Data) {
        guard message.count >= Self.headerLength, message.first == SendspinBinaryType.audioChunk else { return nil }
        let bytes = [UInt8](message.prefix(Self.headerLength))
        var timestamp: UInt64 = 0
        for byte in bytes[1 ... 8] {
            timestamp = timestamp << 8 | UInt64(byte)
        }
        var sendAhead: UInt32 = 0
        for byte in bytes[9 ... 12] {
            sendAhead = sendAhead << 8 | UInt32(byte)
        }
        self.timestamp = Int64(bitPattern: timestamp)
        self.sendAhead = sendAhead
        self.payload = Data(message.dropFirst(Self.headerLength))
    }
}
