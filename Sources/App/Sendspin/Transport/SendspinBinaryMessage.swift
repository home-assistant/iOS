import Foundation

/// A decrypted binary frame, identified by the message ID in its first byte.
enum SendspinBinaryMessage {
    /// ID 0: a JSON message body, the same envelope the cleartext handshake uses.
    case json(Data)
    /// ID 4: a player-role audio chunk.
    case audio(SendspinAudioChunk)
    /// An ID belonging to a role this client never activates.
    case unhandled(id: UInt8)

    static let jsonMessageId: UInt8 = 0
    static let fragmentMessageId: UInt8 = 1
    static let audioMessageId: UInt8 = 4

    /// Wraps a JSON body in the frame the encrypted channel expects.
    static func jsonFrame(_ body: Data) -> Data {
        var frame = Data([jsonMessageId])
        frame.append(body)
        return frame
    }

    init(id: UInt8, payload: Data) {
        switch id {
        case Self.jsonMessageId:
            self = .json(payload)
        case Self.audioMessageId:
            if let chunk = SendspinAudioChunk(payload: payload) {
                self = .audio(chunk)
            } else {
                self = .unhandled(id: id)
            }
        default:
            self = .unhandled(id: id)
        }
    }
}
