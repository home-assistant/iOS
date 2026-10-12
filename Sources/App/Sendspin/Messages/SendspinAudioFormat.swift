import Foundation

/// One audio format a player can play, or the one a stream uses.
struct SendspinAudioFormat: Codable, Equatable, Hashable {
    let codec: String
    let channels: Int
    let sampleRate: Int
    let bitDepth: Int

    enum CodingKeys: String, CodingKey {
        case codec
        case channels
        case sampleRate = "sample_rate"
        case bitDepth = "bit_depth"
    }
}
