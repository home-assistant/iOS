import Foundation

/// Codecs the Sendspin player role can negotiate. This client only ever advertises `pcm`, but the
/// other cases exist so a `stream/start` naming one is recognised and reported instead of ignored.
enum SendspinAudioCodec: String, Codable, Hashable {
    case pcm
    case flac
    case opus
}
