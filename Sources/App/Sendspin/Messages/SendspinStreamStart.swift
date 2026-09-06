import Foundation

/// A decoded `stream/start`. Only the player object is modelled: this client never activates the
/// artwork or visualizer roles, so a server may not start their streams.
struct SendspinStreamStart: Decodable, Equatable {
    struct Player: Decodable, Equatable {
        let format: SendspinAudioFormat
        /// Standard base64 in the payload; required for FLAC, absent for PCM and Opus.
        let codecHeader: Data?

        enum CodingKeys: String, CodingKey {
            case codecHeader = "codec_header"
        }

        init(from decoder: Decoder) throws {
            format = try SendspinAudioFormat(from: decoder)
            let container = try decoder.container(keyedBy: CodingKeys.self)
            codecHeader = try container
                .decodeIfPresent(String.self, forKey: .codecHeader)
                .flatMap { Data(base64Encoded: $0) }
        }
    }

    let serverTransmitted: Int64
    let player: Player?

    enum CodingKeys: String, CodingKey {
        case serverTransmitted = "server_transmitted"
        case player
    }
}
