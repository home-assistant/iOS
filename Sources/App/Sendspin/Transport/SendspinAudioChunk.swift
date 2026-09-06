import Foundation

/// A player-role binary audio message: when the first sample should leave the audio port, how much
/// lead the server had when it sent the chunk, and the encoded frames themselves.
struct SendspinAudioChunk: Equatable {
    /// Server clock time in microseconds for the chunk's first sample.
    let serverTimestamp: Int64
    /// Microseconds between the server's transmission and `serverTimestamp`. Both saturation values
    /// mean "no lead measured", so neither is usable as a delay sample.
    let sendAhead: UInt32
    let data: Data

    static let headerLength = 12

    /// `send_ahead` saturates rather than wrapping, so the extremes carry no timing information.
    var hasMeasurableLead: Bool {
        sendAhead != 0 && sendAhead != UInt32.max
    }

    init?(payload: Data) {
        guard payload.count > Self.headerLength else { return nil }
        let header = [UInt8](payload.prefix(Self.headerLength))
        var timestamp: UInt64 = 0
        for index in 0 ..< 8 {
            timestamp = (timestamp << 8) | UInt64(header[index])
        }
        var lead: UInt32 = 0
        for index in 8 ..< 12 {
            lead = (lead << 8) | UInt32(header[index])
        }
        serverTimestamp = Int64(bitPattern: timestamp)
        sendAhead = lead
        data = Data(payload.dropFirst(Self.headerLength))
    }
}
